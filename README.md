# Laravel Docker 开发环境

基于 Docker 的 Laravel 开发环境，支持 PHP 8.4 + Nginx 和 Caddy 两种部署模式，提供完整的开发工具链和交互式管理界面。

## ✨ 主要特性

- 🐳 **Docker 容器化**：完全容器化的开发环境，确保环境一致性
- 🚀 **PHP 8.4**：基于 serversideup/php:8.4-fpm-nginx 镜像
- 🔧 **双模式支持**：支持 Nginx 直接模式和 Caddy 反向代理模式
- 📊 **性能优化**：预配置 OPcache、PHP-FPM 优化设置
- 🛠️ **交互式管理**：提供友好的命令行管理工具
- 📝 **完整日志**：集成日志管理和实时监控
- 🔒 **安全配置**：生产级安全配置和权限管理

## 🏗️ 架构概览

### 部署模式

#### 模式一：Nginx 直接模式（推荐用于开发）
```
浏览器 → Nginx (容器内) → PHP-FPM → Laravel
```
- 端口：80
- 配置文件：`docker/docker-compose.yaml`
- 特点：简单直接，适合开发环境

#### 模式二：Caddy 反向代理模式（推荐用于生产）
```
浏览器 → Caddy → PHP-FPM → Laravel
```
- 端口：80/443
- 配置文件：`docker/docker-compose-caddy.yaml`
- 特点：自动 HTTPS，适合生产环境

### 目录结构

```
├── docker/                 # Docker 配置目录
│   ├── .env               # 环境变量配置
│   ├── docker-compose.yaml        # Nginx 模式配置
│   ├── docker-compose-caddy.yaml  # Caddy 模式配置
│   ├── start.sh           # 交互式管理脚本
│   ├── php-fpm-nginx/     # PHP-FPM + Nginx 镜像
│   ├── caddy/             # Caddy 配置
│   └── appdata/           # 持久化数据
└── www/                   # Laravel 应用代码
```

## 🚀 快速开始

### 环境要求

- Docker 20.10+
- Docker Compose 2.0+
- Git

### 安装步骤

1. **克隆项目**
```bash
git clone <repository-url>
cd caddy_laravel
```

2. **配置环境变量**
```bash
# 检查并修改 docker/.env 文件
cp docker/.env.example docker/.env  # 如果需要
```

3. **启动服务**
```bash
# 使用交互式管理工具（推荐）
./docker/start.sh

# 或直接使用 Docker Compose
cd docker

# Nginx 模式（默认）
docker-compose up -d

# Caddy 模式
docker-compose -f docker-compose-caddy.yaml up -d
```

4. **访问应用**
- Nginx 模式：http://localhost
- Caddy 模式：http://localhost 或 https://laravel.test

## 🛠️ 管理工具

### 交互式管理脚本

运行 `./docker/start.sh` 启动交互式管理界面：

```
=== Docker Compose 管理工具 ===
请选择要执行的操作：
1. 启动服务 (后台运行)
2. 关闭服务
3. 进入 PHP-FPM 容器
4. 进入 Caddy 容器
5. 安装 Composer 依赖
6. Laravel 缓存优化
7. Laravel 清理全部缓存
8. 查看所有服务日志 (最近50行)
9. 查看 PHP-FPM 日志 (最近100行)
a. 查看 Caddy 日志 (最近100行)
b. 实时跟踪所有服务日志
c. 重新构建并重启服务
d. 设置 www 目录权限 (www-data)
e. 查看 Docker 网络信息 (Gateway)
0. 退出
```

### 常用命令

```bash
# 启动服务
./docker/start.sh  # 选择选项 1

# 进入 PHP 容器
./docker/start.sh  # 选择选项 3

# 安装依赖
./docker/start.sh  # 选择选项 5

# 查看日志
./docker/start.sh  # 选择选项 8

# 设置权限
./docker/start.sh  # 选择选项 d
```

## ⚙️ 配置说明

### 环境变量配置

编辑 `docker/.env` 文件：

```bash
# 端口配置
NGINX_PORT=80
CADDY_HTTP_PORT=80
CADDY_HTTPS_PORT=443

# 路径配置
APP_CODE_PATH_HOST=../www
APP_CODE_PATH_CONTAINER=/var/www/html

# PHP 配置
PHP_MEMORY_LIMIT=256M
PHP_MAX_EXECUTION_TIME=120
PHP_UPLOAD_MAX_FILE_SIZE=1000M

# Laravel 配置
APP_ENV=production
APP_DEBUG=false
```

### PHP 性能优化

项目预配置了以下优化设置：

- **OPcache**：启用代码缓存，提升性能
- **PHP-FPM**：动态进程管理，优化内存使用
- **上传限制**：支持大文件上传（最大 1GB）
- **执行时间**：适合长时间运行的任务

### 网络配置

- **Nginx 模式**：容器直接暴露端口 80
- **Caddy 模式**：支持 HTTP/HTTPS，自动证书管理
- **内部通信**：容器间通过 Docker 网络通信

#### 获取容器 IP 地址

```bash
# 查看 Docker 网络信息（包含 Gateway）
./docker/start.sh  # 选择选项 e

# 获取特定容器的 IP 地址
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <容器名>

# 从主机访问容器
ping <容器IP>
curl http://<容器IP>:8080
```

## 🔧 开发工作流

### 日常开发

1. **启动环境**
```bash
./docker/start.sh  # 选择选项 1
```

2. **安装依赖**
```bash
./docker/start.sh  # 选择选项 5
```

3. **开发调试**
```bash
# 进入容器
./docker/start.sh  # 选择选项 3

# 在容器内执行 Laravel 命令
php artisan migrate
php artisan serve
```

4. **查看日志**
```bash
./docker/start.sh  # 选择选项 8 或 b
```

### 缓存管理

```bash
# 优化缓存（生产环境）
./docker/start.sh  # 选择选项 6

# 清理缓存（开发环境）
./docker/start.sh  # 选择选项 7
```

## 🐛 故障排除

### 常见问题

1. **端口占用**
```bash
# 检查端口占用
lsof -i :80
# 修改 docker/.env 中的端口配置
```

2. **权限问题**
```bash
# 设置正确的文件权限
./docker/start.sh  # 选择选项 d
```

3. **容器无法启动**
```bash
# 查看详细日志
./docker/start.sh  # 选择选项 8
# 重新构建容器
./docker/start.sh  # 选择选项 c
```

### 日志查看

```bash
# 查看所有服务日志
./docker/start.sh  # 选择选项 8

# 实时跟踪日志
./docker/start.sh  # 选择选项 b

# 查看特定服务日志
./docker/start.sh  # 选择选项 9 (PHP-FPM)
./docker/start.sh  # 选择选项 a (Caddy)
```

### 性能优化

1. **启用 OPcache**（已默认启用）
2. **调整 PHP-FPM 进程数**：编辑 `docker/.env`
3. **优化 Laravel 缓存**：使用选项 6
4. **监控资源使用**：使用 `docker stats`

## 📚 更多信息

- [Laravel 官方文档](https://laravel.com/docs)
- [Docker 官方文档](https://docs.docker.com/)
- [Caddy 官方文档](https://caddyserver.com/docs/)
- [ServerSideUp PHP 镜像](https://serversideup.net/open-source/docker-php/)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 📄 许可证

本项目采用 MIT 许可证。

## 打赏

![alt text](image.png)