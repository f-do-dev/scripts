#!/bin/bash

# 更新软件包索引
sudo apt update

# 安装 wget 和 bash（大多数系统已有 bash，此处仅保险起见）
sudo apt install -y wget bash

# 安装 Docker
wget -qO- https://get.docker.com/ | sudo bash

# 创建持久化数据目录
mkdir -p /home/ubuntu/data/mysql

# 生成随机密码
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 16)

echo "✅ 开始安装 Docker、MySQL (Docker 容器) 并部署 new-api..."

# 运行 MySQL Docker 容器
sudo docker run --name mysql -d \
  --restart always \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
  -e MYSQL_DATABASE="oneapi" \
  -v /home/ubuntu/data/mysql:/var/lib/mysql \
  mysql:latest

# 等待 MySQL 启动 (使用一个简单的循环来检查端口是否打开)
echo "⏳ 等待 MySQL 启动..."
until nc -z localhost 3306; do
  sleep 2
done
echo "✅ MySQL 启动完成!"

# 运行 new-api Docker 容器，配置 MySQL 连接
sudo docker run --name new-api -d \
  --restart always \
  -p 80:3000 \
  -e SQL_DSN="root:${MYSQL_ROOT_PASSWORD}@tcp(localhost:3306)/oneapi" \
  -e TZ=Asia/Shanghai \
  -v /home/ubuntu/data/new-api:/data \
  --link mysql:mysql \
  calciumion/new-api:latest

echo "✅ Docker 容器 new-api 部署完成！"
echo "⚠️  MySQL root 密码：${MYSQL_ROOT_PASSWORD}  请妥善保管！"
