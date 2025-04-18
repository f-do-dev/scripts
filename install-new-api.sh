#!/bin/bash

# 更新软件包索引
sudo apt update

# 安装依赖
sudo apt install -y wget bash netcat

# 安装 Docker
wget -qO- https://get.docker.com/ | sudo bash

# 创建持久化目录
mkdir -p /home/ubuntu/data/mysql /home/ubuntu/data/new-api

# 生成随机密码
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 16)
echo "${MYSQL_ROOT_PASSWORD}" > /home/ubuntu/mysql_root_password.txt
chmod 600 /home/ubuntu/mysql_root_password.txt

echo "✅ 开始安装 Docker、MySQL (Docker 容器) 并部署 new-api..."

# 创建 Docker 网络
docker network create app-network || true

# 启动 MySQL
sudo docker run --name mysql -d \
  --network app-network \
  --restart always \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
  -e MYSQL_DATABASE="oneapi" \
  -v /home/ubuntu/data/mysql:/var/lib/mysql \
  mysql:latest

# 等待 MySQL 启动
echo "⏳ 等待 MySQL 启动..."
until nc -z localhost 3306; do
  sleep 2
done
echo "✅ MySQL 启动完成!"

# 启动 new-api
sudo docker run --name new-api -d \
  --network app-network \
  --restart always \
  -p 80:3000 \
  -e SQL_DSN="root:${MYSQL_ROOT_PASSWORD}@tcp(mysql:3306)/oneapi" \
  -e TZ=Asia/Shanghai \
  -v /home/ubuntu/data/new-api:/data \
  calciumion/new-api:latest

echo "✅ Docker 容器 new-api 部署完成！"
echo "⚠️  MySQL root 密码：${MYSQL_ROOT_PASSWORD} （也已保存至 /home/ubuntu/mysql_root_password.txt）"
