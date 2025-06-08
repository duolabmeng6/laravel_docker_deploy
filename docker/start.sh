#!/bin/bash

# Docker Compose 管理脚本
# 原始命令备份：
# docker-compose up -d # 后台运行
# docker-compose down # 关闭服务器
# docker-compose exec php-fpm bash # 进入php-fpm容器
# docker-compose exec caddy bash # 进入caddy容器
# docker-compose exec php-fpm composer install # 安装依赖

# 自动检测并切换到正确的工作目录
detect_project_root() {
    local current_dir="$(pwd)"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 如果脚本在docker目录中，则项目根目录是上一级
    if [[ "$(basename "$script_dir")" == "docker" ]]; then
        local project_root="$(dirname "$script_dir")"
        echo -e "${YELLOW}检测到项目根目录: ${project_root}${NC}"
        cd "$project_root" || {
            echo -e "${RED}错误: 无法切换到项目根目录${NC}"
            exit 1
        }
    # 检查当前目录是否有docker-compose.yaml文件
    elif [[ -f "docker/docker-compose.yaml" ]]; then
        echo -e "${GREEN}当前已在项目根目录${NC}"
    else
        echo -e "${RED}错误: 未找到docker/docker-compose.yaml文件${NC}"
        echo -e "${YELLOW}请确保在正确的项目目录中运行此脚本${NC}"
        exit 1
    fi
}

# 检查并验证 .env 文件
check_env_file() {
    local env_file="docker/.env"

    echo -e "\n${CYAN}=== 环境配置检查 ===${NC}"

    if [[ -f "$env_file" ]]; then
        echo -e "${GREEN}✓ 找到 .env 文件: $env_file${NC}"

        # 显示关键环境变量
        echo -e "${YELLOW}关键环境变量：${NC}"
        if grep -q "APP_CODE_PATH_HOST" "$env_file"; then
            local host_path=$(grep "APP_CODE_PATH_HOST" "$env_file" | cut -d'=' -f2)
            echo -e "  APP_CODE_PATH_HOST=${GREEN}$host_path${NC}"
        fi

        if grep -q "APP_CODE_PATH_CONTAINER" "$env_file"; then
            local container_path=$(grep "APP_CODE_PATH_CONTAINER" "$env_file" | cut -d'=' -f2)
            echo -e "  APP_CODE_PATH_CONTAINER=${GREEN}$container_path${NC}"
        fi

        # 检查主机路径是否存在
        local host_path=$(grep "APP_CODE_PATH_HOST" "$env_file" | cut -d'=' -f2)
        if [[ -n "$host_path" ]]; then
            # 处理相对路径
            local full_path
            if [[ "$host_path" == ../* ]]; then
                full_path="docker/$host_path"
            else
                full_path="$host_path"
            fi

            if [[ -d "$full_path" ]]; then
                echo -e "  ${GREEN}✓ 主机代码路径存在: $full_path${NC}"
            else
                echo -e "  ${RED}✗ 主机代码路径不存在: $full_path${NC}"
                echo -e "  ${YELLOW}警告: 这可能导致容器无法正常挂载代码目录${NC}"
            fi
        fi

    else
        echo -e "${RED}✗ 未找到 .env 文件: $env_file${NC}"
        echo -e "${YELLOW}警告: Docker Compose 可能无法正确加载环境变量${NC}"
        echo -e "${BLUE}建议创建 .env 文件并配置必要的环境变量${NC}"
        return 1
    fi
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Docker Compose 配置文件路径和环境文件
COMPOSE_FILE="docker/docker-compose.yaml"
ENV_FILE="docker/.env"

# Docker Compose 命令辅助函数
dc() {
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
}

# 检查服务状态
check_service_status() {
    echo -e "\n${CYAN}=== 服务状态 ===${NC}"
    if dc ps --services --filter "status=running" | grep -q .; then
        echo -e "${GREEN}运行中的服务：${NC}"
        dc ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" | grep -E "(Up|running)"
    else
        echo -e "${YELLOW}当前没有运行中的服务${NC}"
    fi
}

# 显示菜单
show_menu() {
    check_service_status
    echo -e "\n${CYAN}=== Docker Compose 管理工具 ===${NC}"
    echo -e "${YELLOW}请选择要执行的操作：${NC}"
    echo -e "${GREEN}1.${NC} 启动服务 (后台运行)"
    echo -e "${GREEN}2.${NC} 关闭服务"
    echo -e "${GREEN}3.${NC} 进入 PHP-FPM 容器"
    echo -e "${GREEN}4.${NC} 进入 Caddy 容器"
    echo -e "${GREEN}5.${NC} 安装 Composer 依赖"
    echo -e "${CYAN}6.${NC} Laravel 缓存优化"
    echo -e "${CYAN}7.${NC} Laravel 清理全部缓存"
    echo -e "${PURPLE}8.${NC} 查看所有服务日志 (最近50行)"
    echo -e "${PURPLE}9.${NC} 查看 PHP-FPM 日志 (最近100行)"
    echo -e "${PURPLE}a.${NC} 查看 Caddy 日志 (最近100行)"
    echo -e "${PURPLE}b.${NC} 实时跟踪所有服务日志"
    echo -e "${YELLOW}c.${NC} 重新构建并重启服务"
    echo -e "${YELLOW}d.${NC} 设置 www 目录权限 (www-data)"
    echo -e "${RED}0.${NC} 退出"
    echo -e "${BLUE}================================${NC}"
}

# 执行命令并显示结果
execute_command() {
    local cmd="$1"
    local desc="$2"

    echo -e "\n${YELLOW}正在执行: ${desc}${NC}"
    echo -e "${PURPLE}命令: ${cmd}${NC}"

    if eval "$cmd"; then
        echo -e "${GREEN}✓ 执行成功${NC}"
    else
        echo -e "${RED}✗ 执行失败${NC}"
    fi
}

# 危险操作确认函数
confirm_dangerous_operation() {
    local operation="$1"
    local warning="$2"

    echo -e "\n${RED}⚠️  危险操作警告 ⚠️${NC}"
    echo -e "${YELLOW}操作: ${operation}${NC}"
    echo -e "${YELLOW}影响: ${warning}${NC}"
    echo -e "${RED}此操作不可撤销！${NC}"

    echo -n -e "\n${CYAN}确认执行此操作吗？请输入 'yes' 确认，其他任意键取消: ${NC}"
    read -r confirmation

    if [[ "$confirmation" == "yes" ]]; then
        echo -e "${GREEN}✓ 操作已确认${NC}"
        return 0
    else
        echo -e "${YELLOW}✗ 操作已取消${NC}"
        return 1
    fi
}

# Laravel 缓存优化
laravel_cache_optimize() {
    if dc ps php-fpm | grep -q "Up"; then
        echo -e "\n${YELLOW}正在执行 Laravel 缓存优化...${NC}"
        echo -e "${PURPLE}执行以下命令：${NC}"
        echo -e "  - php artisan config:cache"
        echo -e "  - php artisan route:cache"
        echo -e "  - php artisan view:cache"
        echo -e "  - php artisan event:cache"

        dc exec php-fpm php artisan config:cache && \
        dc exec php-fpm php artisan route:cache && \
        dc exec php-fpm php artisan view:cache && \
        dc exec php-fpm php artisan event:cache

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Laravel 缓存优化完成${NC}"
        else
            echo -e "${RED}✗ Laravel 缓存优化失败${NC}"
        fi
    else
        echo -e "\n${RED}错误: PHP-FPM 服务未运行，请先启动服务 (选项1)${NC}"
    fi
}

# Laravel 清理全部缓存
laravel_cache_clear() {
    if dc ps php-fpm | grep -q "Up"; then
        echo -e "\n${YELLOW}正在清理 Laravel 全部缓存...${NC}"
        echo -e "${PURPLE}执行以下命令：${NC}"
        echo -e "  - php artisan cache:clear"
        echo -e "  - php artisan config:clear"
        echo -e "  - php artisan route:clear"
        echo -e "  - php artisan view:clear"
        echo -e "  - php artisan event:clear"
        echo -e "  - php artisan optimize:clear"

        dc exec php-fpm php artisan cache:clear && \
        dc exec php-fpm php artisan config:clear && \
        dc exec php-fpm php artisan route:clear && \
        dc exec php-fpm php artisan view:clear && \
        dc exec php-fpm php artisan event:clear && \
        dc exec php-fpm php artisan optimize:clear

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Laravel 全部缓存清理完成${NC}"
        else
            echo -e "${RED}✗ Laravel 缓存清理失败${NC}"
        fi
    else
        echo -e "\n${RED}错误: PHP-FPM 服务未运行，请先启动服务 (选项1)${NC}"
    fi
}

# 设置 www 目录权限为 www-data 用户
set_www_permissions() {
    local www_path="./www"
    local abs_path="$(cd "$www_path" 2>/dev/null && pwd)"

    echo -e "\n${YELLOW}正在设置 www 目录权限...${NC}"
    echo -e "${PURPLE}目标路径: ${www_path}${NC}"
    if [[ -n "$abs_path" ]]; then
        echo -e "${PURPLE}绝对路径: ${abs_path}${NC}"
    fi
    echo -e "${PURPLE}权限设置: UID:GID 33:33 (www-data)${NC}"

    # 检查目录是否存在
    if [[ ! -d "$www_path" ]]; then
        echo -e "${RED}✗ 错误: www 目录不存在${NC}"
        echo -e "${YELLOW}当前工作目录: $(pwd)${NC}"
        echo -e "${YELLOW}查找路径: $www_path${NC}"
        return 1
    fi

    # 显示当前权限信息
    echo -e "\n${CYAN}当前权限信息：${NC}"
    ls -la "$www_path" | head -5

    # 执行权限设置命令
    echo -e "\n${YELLOW}执行命令: chown -R 33:33 $www_path${NC}"
    if chown -R 33:33 "$www_path"; then
        echo -e "${GREEN}✓ www 目录权限设置成功${NC}"

        # 显示设置后的权限信息
        echo -e "\n${CYAN}设置后权限信息：${NC}"
        ls -la "$www_path" | head -5

        echo -e "\n${GREEN}权限设置完成！Laravel 应用现在应该可以正常访问文件了。${NC}"
    else
        echo -e "${RED}✗ www 目录权限设置失败${NC}"
        echo -e "${YELLOW}提示: 可能需要 sudo 权限来执行此操作${NC}"
        return 1
    fi
}

# 重新构建并重启服务
rebuild_and_restart() {
    echo -e "\n${YELLOW}正在重新构建并重启服务...${NC}"
    echo -e "${PURPLE}执行以下步骤：${NC}"
    echo -e "  1. 停止所有服务"
    echo -e "  2. 重新构建镜像"
    echo -e "  3. 启动服务"
    echo

    # 步骤1: 停止服务
    echo -e "${YELLOW}步骤 1/3: 停止所有服务...${NC}"
    if dc down; then
        echo -e "${GREEN}✓ 服务停止成功${NC}"
    else
        echo -e "${RED}✗ 服务停止失败${NC}"
        return 1
    fi

    # 步骤2: 重新构建
    echo -e "\n${YELLOW}步骤 2/3: 重新构建镜像...${NC}"
    echo -e "${PURPLE}命令: dc build${NC}"
    if dc build; then
        echo -e "${GREEN}✓ 镜像构建成功${NC}"
    else
        echo -e "${RED}✗ 镜像构建失败${NC}"
        return 1
    fi

    # 步骤3: 启动服务
    echo -e "\n${YELLOW}步骤 3/3: 启动服务...${NC}"
    echo -e "${PURPLE}命令: dc up -d${NC}"
    if dc up -d; then
        echo -e "${GREEN}✓ 服务启动成功${NC}"
        echo -e "\n${GREEN}🎉 重新构建并重启完成！${NC}"
    else
        echo -e "${RED}✗ 服务启动失败${NC}"
        return 1
    fi
}

# 检测并切换到正确的工作目录
detect_project_root

# 检查环境配置
check_env_file

# 主循环
while true; do
    show_menu
    echo -n -e "${CYAN}请输入选项 (0-9, a-d): ${NC}"
    read -r choice

    case $choice in
        1)
            execute_command "dc up -d" "启动服务 (后台运行)"
            ;;
        2)
            if confirm_dangerous_operation "关闭所有Docker服务" "将停止所有运行中的容器，可能影响正在进行的工作"; then
                execute_command "dc down" "关闭服务"
            fi
            ;;
        3)
            if dc ps php-fpm | grep -q "Up"; then
                echo -e "\n${YELLOW}正在进入 PHP-FPM 容器...${NC}"
                echo -e "${PURPLE}命令: dc exec php-fpm bash${NC}"
                dc exec php-fpm bash
            else
                echo -e "\n${RED}错误: PHP-FPM 服务未运行，请先启动服务 (选项1)${NC}"
            fi
            ;;
        4)
            if dc ps caddy | grep -q "Up"; then
                echo -e "\n${YELLOW}正在进入 Caddy 容器...${NC}"
                echo -e "${PURPLE}命令: dc exec caddy sh${NC}"
                dc exec caddy sh
            else
                echo -e "\n${RED}错误: Caddy 服务未运行，请先启动服务 (选项1)${NC}"
            fi
            ;;
        5)
            if dc ps php-fpm | grep -q "Up"; then
                execute_command "dc exec php-fpm composer install" "安装 Composer 依赖"
            else
                echo -e "\n${RED}错误: PHP-FPM 服务未运行，请先启动服务 (选项1)${NC}"
            fi
            ;;
        6)
            laravel_cache_optimize
            ;;
        7)
            if confirm_dangerous_operation "清理Laravel全部缓存" "将清除所有缓存，可能暂时影响应用性能"; then
                laravel_cache_clear
            fi
            ;;
        8)
            echo -e "\n${YELLOW}显示所有服务日志 (最近50行)...${NC}"
            echo -e "${PURPLE}命令: dc logs --tail=50${NC}"
            dc logs --tail=50
            ;;
        9)
            echo -e "\n${YELLOW}显示 PHP-FPM 日志 (最近100行)...${NC}"
            echo -e "${PURPLE}命令: dc logs --tail=100 php-fpm${NC}"
            dc logs --tail=100 php-fpm
            ;;
        a|A)
            echo -e "\n${YELLOW}显示 Caddy 日志 (最近100行)...${NC}"
            echo -e "${PURPLE}命令: dc logs --tail=100 caddy${NC}"
            dc logs --tail=100 caddy
            ;;
        b|B)
            echo -e "\n${YELLOW}实时跟踪所有服务日志...${NC}"
            echo -e "${PURPLE}命令: dc logs -f${NC}"
            echo -e "${RED}提示: 按 Ctrl+C 停止跟踪${NC}"
            dc logs -f
            ;;
        c|C)
            if confirm_dangerous_operation "重新构建并重启所有服务" "将停止所有服务，重新构建镜像并重启，可能需要较长时间"; then
                rebuild_and_restart
            fi
            ;;
        d|D)
            if confirm_dangerous_operation "设置 www 目录权限为 www-data" "将修改 www 目录及其所有子文件/目录的所有权，这可能影响文件访问权限"; then
                set_www_permissions
            fi
            ;;
        0)
            echo -e "\n${GREEN}再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}无效选项，请输入 0-9, a-d${NC}"
            ;;
    esac

    # 等待用户按键继续（跳过退出和实时日志选项）
    if [[ $choice != "0" && $choice != "b" && $choice != "B" ]]; then
        echo -e "\n${BLUE}按任意键继续...${NC}"
        read -n 1 -s
    fi
done
