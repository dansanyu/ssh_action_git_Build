编译的两种方式：

1是在自己的服务器docker中编译（自己服务器编译要设置好限制，不要爆内存）：https://github.com/dansanyu/testwebhook

2是在github服务器上编译：https://github.com/dansanyu/ssh_action_git_Build

都差不多，这里说第二种，在github服务器上编译

项目中的必须要的文件如下：

      myproject/
      ├─ .github/
      │   └─ workflows/
      │       └─ deploy.yml      # 你的 workflow 文件
      ├─ Dockerfile
      ├─ docker-compose.yml
      └─ deploy.sh
      
- .github 是隐藏目录，存放 GitHub 配置
- 
- workflows 目录专门存放 Actions workflow 文件
- 
- 文件可以命名为任意名字，但必须以 .yml 或 .yaml 结尾
- 
每次push github 会按照deploy.yml中的代码执行

deploy.yml示例代码

name: Build online

on:
  push:
    branches:
      - master  # 每次 push master 自动触发

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      # 1️⃣ 拉代码
      - name: Checkout code
        uses: actions/checkout@v3

      # 2️⃣ 设置 Go
      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: 1.26

      # 3️⃣ 编译 Go 二进制
      - name: Build Go binary
        run: |
          GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o app_new

      # 4️⃣ 确保远程目标目录存在
      - name: Ensure target directory exists
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          script: |
            mkdir -p /home/gosrc/gitbuild

      # 4️⃣ 上传二进制到 VPS
      - name: Copy binary to server
        uses: appleboy/scp-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          source: "app_new"
          target: "${{ secrets.WORK_DIR }}/"

      # 5️⃣ 上传 deploy.sh到 VPS
      - name: Copy deploy.sh to server
        uses: appleboy/scp-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          source: "deploy.sh"
          target: "${{ secrets.WORK_DIR }}/"

      # 5️⃣ 上传 docker-compose.yml 到 VPS
      - name: Copy docker-compose.yml to server
        uses: appleboy/scp-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          source: "docker-compose.yml"
          target: "${{ secrets.WORK_DIR }}/"

      # 5️⃣ 上传 Dockerfile 到 VPS
      - name: Copy Dockerfile to server
        uses: appleboy/scp-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          source: "Dockerfile"
          target: "${{ secrets.WORK_DIR }}/"

      # 5️⃣ 上传 ssl 文件夹到 VPS
      - name: Copy ssl folder to server
        uses: appleboy/scp-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          source: "ssl"
          target: "${{ secrets.WORK_DIR }}/"
          recursive: true   # 递归上传整个目录

      # 5️⃣ 在 VPS 上执行 deploy.sh
      - name: Run deploy script on server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          script: |
            cd /home/gosrc/gitbuild
            chmod +x ./deploy.sh
            bash deploy.sh
- on.push.branches：当指定分支发生 push 时触发 workflow
- 这里监听 master 分支
- ⚠️ 如果你的主要开发在 main，要改成 main

- 功能：把仓库最新代码 clone 下来
- ⚠️ 默认 clone 深度 1，如果需要完整历史（比如 git pull 子模块）要加 fetch-depth: 0

- 安装 Go 1.26
- ⚠️ 版本必须和你本地开发一致，避免编译不兼容

- 核心操作：交叉编译生成 Linux 静态二进制
- 参数解释：
- GOOS=linux → Linux 系统
- GOARCH=amd64 → x86_64 架构
- CGO_ENABLED=0 → 禁用 CGO，生成静态二进制 → Alpine 容器可直接运行
- 输出文件：app_new
- ⚠️ 坑：
a.没设置 CGO_ENABLED=0 → 在 Alpine 容器里运行可能报 exec ./app: no such file or directory
b.输出路径要和 docker-compose / deploy.sh 挂载一致

- 功能：SSH 到 VPS，确保部署目录存在
- mkdir -p → 如果目录已存在不会报错
- ⚠️ 坑：如果 WORK_DIR 和这里路径不一致，后续上传会失败

- 上传 app_new 到 VPS
- ⚠️ 注意：
- source 是本地 Actions 的相对路径
- target 是 VPS 的目录
- 必须保证 deploy.sh 和 docker-compose.yml 挂载路径匹配

- SSH 到 VPS 执行部署脚本
- chmod +x → 保证脚本可执行
- ⚠️ 坑：
a.如果 WORK_DIR 与这里不同，脚本找不到
b.如果 deploy.sh 没有 chmod +x 或 set -e，出错不会停止
🔑 总结
1.核心思路：Actions 构建 Linux 静态二进制 → SCP 上传 VPS → Docker Compose 启动
2.静态编译：必须 CGO_ENABLED=0，否则 Alpine 报 no such file or directory
3.Secrets：
- SERVER_HOST, SERVER_USER, SERVER_SSH_KEY → SSH 登陆 VPS
- WORK_DIR → VPS 部署目录
4.scp 文件夹上传：必须加 recursive: true
5.VPS deploy.sh：
- 停止旧容器
- chmod +x 二进制
- Docker Compose up
6.挂载目录一致性：
- Docker Compose 的 volumes 路径要和 SCP 上传路径对应
- 
7.script:下的执行代码不能是${{ secrets.SERVER_HOST }}：
          script: |
            cd /home/gosrc/gitbuild
            chmod +x ./deploy.sh
            bash deploy.sh
  
deploy.sh示例代码:

          #!/bin/bash
          set -e
          
          PROJECT_DIR="/home/gosrc/gitbuild"
          
          # 创建项目目录
          mkdir -p $PROJECT_DIR
          cd $PROJECT_DIR
          
          # 停掉旧容器 停掉当前目录下 docker-compose.yml 定义的所有服务
          docker compose down || true
          
          # 替换二进制
          mv app app_old 2>/dev/null || true
          mv app_new app 2>/dev/null || true
          
          # 构建并启动容器
          docker compose build
          docker compose up -d --build

docker-compose.yml示例代码:

          version: "3.9"
          
          services:
            app:
              image: alpine:latest
              container_name: gogo
              working_dir: /app
              command: ["./app"]               # 启动挂载的二进制
              ports:
                - "8081:8081"
              volumes:
                - ./app:/app/app               # 挂载二进制文件
                - ./ssl:/app/ssl               # 挂载 ssl 文件夹
              restart: always

              
Dockerfile示例代码:

              # 运行镜像只需要二进制
              FROM alpine:latest
              WORKDIR /app
              
              # 拷贝从 Actions 上传的二进制
              COPY app .
              
              RUN chmod +x app
              
              # 开放端口
              EXPOSE 8081
              
              # 启动应用
              CMD ["./app"]
