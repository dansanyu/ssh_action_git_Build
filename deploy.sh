#!/bin/bash
set -e

PROJECT_DIR="/home/gosrc/gitbuild"

# 创建项目目录
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 停掉旧容器 停掉当前目录下 docker-compose.yml 定义的所有服务
docker compose down || true

# 替换二进制
mv app app.old 2>/dev/null || true
mv app.new app 2>/dev/null || true

# 构建并启动容器
docker compose build
docker compose up -d --build