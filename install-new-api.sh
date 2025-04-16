#!/bin/bash

# 更新软件包索引
sudo apt update

# 安装 wget 和 bash（大多数系统已有 bash，此处仅保险起见）
sudo apt install -y wget bash

# 安装 Docker
wget -qO- https://get.docker.com/ | sudo bash

# 创建持久化数据目录
mkdir -p /home/ubuntu/data/new-api

# 运行 Docker 容器
sudo docker run --name new-api -d \
  --restart always \
  -p 3000:3000 \
  -e TZ=Asia/Shanghai \
  -v /home/ubuntu/data/new-api:/data \
  calciumion/new-api:latest
