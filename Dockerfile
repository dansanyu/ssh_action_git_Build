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