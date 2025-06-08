#!/bin/bash

# =============================================================================
# Docker镜像加速器简单检测配置脚本
# 功能：检测可用的Docker Hub镜像加速器并配置到系统
# 作者：AI Assistant
# 版本：1.0
# =============================================================================

set -eo pipefail  # 严格模式：遇到错误立即退出（但允许未定义变量）

# =============================================================================
# 配置变量
# =============================================================================

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# 脚本配置
readonly SCRIPT_NAME="Docker镜像加速器配置工具"
readonly VERSION="1.0"
readonly DOCKER_CONFIG_DIR="/etc/docker"
readonly DOCKER_CONFIG_FILE="${DOCKER_CONFIG_DIR}/daemon.json"

# 检测配置
readonly TIMEOUT=5          # curl超时时间（秒）

# 镜像列表
readonly MIRRORS=(
    "https://docker.1panel.live"
    "https://docker.1ms.run"
    "https://docker.mybacc.com"
    "https://dytt.online"
    "https://lispy.org"
    "https://docker.xiaogenban1993.com"
    "https://docker.yomansunter.com"
    "https://aicarbon.xyz"
    "https://666860.xyz"
    "https://a.ussh.net"
    "https://hub.littlediary.cn"
    "https://hub.rat.dev"
    "https://docker.m.daocloud.io"
)

# =============================================================================
# 工具函数
# =============================================================================

# 日志输出函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示脚本标题
show_banner() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  ${SCRIPT_NAME}"
    echo "  版本: ${VERSION}"
    echo "=============================================="
    echo -e "${NC}"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# 镜像检测功能
# =============================================================================

# 测试单个镜像的连通性
test_mirror() {
    local mirror="$1"
    local test_url="${mirror}/v2/"
    
    printf "测试镜像: %-40s " "$mirror"
    
    # 执行curl测试
    if curl -s --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
        --user-agent "Docker-Mirror-Test/1.0" \
        "$test_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 可用${NC}"
        return 0
    else
        echo -e "${RED}✗ 不可用${NC}"
        return 1
    fi
}

# 检测所有镜像并返回可用的
get_working_mirrors() {
    local working_mirrors=()
    
    log_info "开始检测镜像连通性..."
    echo
    
    for mirror in "${MIRRORS[@]}"; do
        if test_mirror "$mirror"; then
            working_mirrors+=("$mirror")
        fi
    done
    
    echo
    if [[ ${#working_mirrors[@]} -gt 0 ]]; then
        log_success "发现 ${#working_mirrors[@]} 个可用镜像"
        printf '%s\n' "${working_mirrors[@]}"
    else
        log_error "没有发现可用的镜像地址！"
        return 1
    fi
}

# =============================================================================
# 配置管理功能
# =============================================================================

# 备份现有Docker配置
backup_docker_config() {
    if [[ -f "$DOCKER_CONFIG_FILE" ]]; then
        local backup_file="${DOCKER_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$DOCKER_CONFIG_FILE" "$backup_file"
        log_success "已备份现有配置到: $backup_file"
        echo "$backup_file"
    else
        log_info "未发现现有Docker配置文件"
        echo ""
    fi
}

# 生成Docker daemon.json配置
generate_docker_config() {
    local mirrors=("$@")
    
    log_info "生成Docker配置文件..."
    
    # 确保Docker配置目录存在
    mkdir -p "$DOCKER_CONFIG_DIR"
    
    # 生成JSON配置
    cat > "$DOCKER_CONFIG_FILE" << EOF
{
  "registry-mirrors": [
EOF
    
    # 添加镜像地址
    for i in "${!mirrors[@]}"; do
        local mirror="${mirrors[$i]}"
        if [[ $i -eq $((${#mirrors[@]} - 1)) ]]; then
            echo "    \"$mirror\"" >> "$DOCKER_CONFIG_FILE"
        else
            echo "    \"$mirror\"," >> "$DOCKER_CONFIG_FILE"
        fi
    done
    
    cat >> "$DOCKER_CONFIG_FILE" << EOF
  ]
}
EOF
    
    log_success "Docker配置文件已生成"
    
    # 显示配置内容
    echo
    log_info "新的Docker配置内容："
    echo -e "${GREEN}"
    cat "$DOCKER_CONFIG_FILE"
    echo -e "${NC}"
}

# 生成配置命令供非root用户使用
generate_config_commands() {
    local mirrors=("$@")

    log_info "生成Docker配置命令..."
    echo
    echo -e "${YELLOW}请复制并执行以下命令来配置Docker镜像加速器：${NC}"
    echo
    echo -e "${GREEN}# 1. 创建Docker配置目录${NC}"
    echo "sudo mkdir -p $DOCKER_CONFIG_DIR"
    echo
    echo -e "${GREEN}# 2. 备份现有配置（如果存在）${NC}"
    echo "sudo cp $DOCKER_CONFIG_FILE $DOCKER_CONFIG_FILE.backup.\$(date +%Y%m%d_%H%M%S) 2>/dev/null || true"
    echo
    echo -e "${GREEN}# 3. 创建新的Docker配置文件${NC}"
    echo "sudo tee $DOCKER_CONFIG_FILE > /dev/null << 'EOF'"
    echo "{"
    echo "  \"registry-mirrors\": ["

    # 添加镜像地址
    for i in "${!mirrors[@]}"; do
        local mirror="${mirrors[$i]}"
        if [[ $i -eq $((${#mirrors[@]} - 1)) ]]; then
            echo "    \"$mirror\""
        else
            echo "    \"$mirror\","
        fi
    done

    echo "  ]"
    echo "}"
    echo "EOF"
    echo
    echo -e "${GREEN}# 4. 重启Docker服务${NC}"
    if command_exists systemctl; then
        echo "sudo systemctl daemon-reload"
        echo "sudo systemctl restart docker"
    elif command_exists service; then
        echo "sudo service docker restart"
    else
        echo "# 请根据您的系统选择合适的重启命令："
        echo "sudo systemctl restart docker"
        echo "# 或"
        echo "sudo service docker restart"
    fi
    echo
    echo -e "${GREEN}# 5. 验证配置${NC}"
    echo "docker info | grep -A 10 'Registry Mirrors'"
    echo
    log_success "配置命令已生成完成！"
}

# =============================================================================
# Docker服务管理
# =============================================================================

# 重启Docker服务
restart_docker() {
    log_info "重启Docker服务..."
    
    if command_exists systemctl; then
        systemctl daemon-reload
        systemctl restart docker
        log_success "Docker服务重启成功"
    elif command_exists service; then
        service docker restart
        log_success "Docker服务重启成功"
    else
        log_warning "无法自动重启Docker服务，请手动执行："
        echo "  sudo systemctl restart docker"
        echo "  # 或"
        echo "  sudo service docker restart"
    fi
}

# =============================================================================
# 主程序
# =============================================================================

# 显示帮助信息
show_help() {
    echo "使用方法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -t, --test     仅测试镜像连通性，不修改配置"
    echo
    echo "示例:"
    echo "  $0              # 检测并配置镜像加速器"
    echo "  $0 -t           # 仅测试镜像连通性"
}

# 用户确认提示
confirm_action() {
    local message="$1"
    echo -e "${YELLOW}$message${NC}"
    read -p "继续吗? [y/N]: " -r response
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 主函数
main() {
    local test_only=0
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--test)
                test_only=1
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # 显示脚本标题
    show_banner

    # 如果只是测试模式，只显示结果
    if [[ "$test_only" == "1" ]]; then
        get_working_mirrors
        log_success "测试完成"
        exit 0
    fi

    # 检查权限并询问用户
    if ! check_root; then
        log_warning "检测到非root用户"
        echo
        if ! confirm_action "是否生成Docker配置命令供您手动执行？"; then
            log_info "操作已取消"
            exit 0
        fi
    else
        log_success "检测到root用户权限"
        echo
        if ! confirm_action "是否继续检测镜像并自动配置Docker？"; then
            log_info "操作已取消"
            exit 0
        fi
    fi

    # 检测镜像
    local working_mirrors=()

    # 配置模式：获取可用镜像列表
    log_info "开始检测镜像连通性..."
    echo

    for mirror in "${MIRRORS[@]}"; do
        if test_mirror "$mirror"; then
            working_mirrors+=("$mirror")
        fi
    done

    echo
    if [[ ${#working_mirrors[@]} -gt 0 ]]; then
        log_success "发现 ${#working_mirrors[@]} 个可用镜像"
    else
        log_error "没有发现可用的镜像地址！"
        exit 1
    fi

    # 根据权限执行不同操作
    if ! check_root; then
        echo
        generate_config_commands "${working_mirrors[@]}"
        exit 0
    fi
    
    # 确认操作
    if ! confirm_action "即将修改Docker配置文件，是否继续？"; then
        log_info "操作已取消"
        exit 0
    fi
    
    # 备份现有配置
    backup_docker_config
    
    # 生成新配置
    generate_docker_config "${working_mirrors[@]}"
    
    # 重启Docker服务
    restart_docker
    
    echo
    log_success "Docker镜像加速器配置完成！"
    echo
    echo "现在您可以正常使用Docker拉取镜像了："
    echo "  docker pull nginx"
    echo "  docker pull mysql"
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
