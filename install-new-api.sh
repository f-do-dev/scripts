#!/bin/bash

# 更新软件包索引
sudo apt update

# 安装必要的软件包
sudo apt install -y wget bash mysql-server pwgen

# 安装 Docker
wget -qO- https://get.docker.com/ | sudo bash

# 创建持久化数据目录
mkdir -p /home/ubuntu/data/new-api

# 生成随机密码
MYSQL_ROOT_PASSWORD=$(pwgen -s 20 1)

# 创建配置文件保存密码
echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD" > /home/ubuntu/data/new-api/mysql_credentials.txt
chmod 600 /home/ubuntu/data/new-api/mysql_credentials.txt

# 启动 MySQL 服务
sudo systemctl start mysql
sudo systemctl enable mysql

# 设置 MySQL root 密码
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"
sudo mysql -e "FLUSH PRIVILEGES;"

# 创建数据库
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS oneapi;"

echo "✅ MySQL 配置完成"
echo "✅ 开始部署 new-api..."

# 运行 Docker 容器
sudo docker run --name new-api -d \
  --restart always \
  --network host \
  -e SQL_DSN="root:${MYSQL_ROOT_PASSWORD}@tcp(localhost:3306)/oneapi" \
  -e TZ=Asia/Shanghai \
  -e GENERATE_DEFAULT_TOKEN=true \
  -e MODEL_MAPPING=gpt-4-turbo-2024-04-09:gpt-4 \
  -v /home/ubuntu/data/new-api:/data \
  lfnull/new-api-magic:v0.6.6.3

echo "✅ new-api 部署完成"

# 等待几秒钟让服务启动
echo "等待服务启动..."
sleep 20

# 执行初始化 SQL 语句
echo "开始执行数据库初始化..."
sudo mysql -u root -p"$MYSQL_ROOT_PASSWORD" oneapi << 'EOF'
INSERT INTO `abilities` (`group`, `model`, `channel_id`, `enabled`, `priority`, `weight`, `tag`) VALUES
('default', 'gpt-4-1106-preview', 1, 1, 0, 0, '');

INSERT INTO `channels` (`id`, `type`, `key`, `open_ai_organization`, `test_model`, `status`, `name`, `weight`, `created_time`, `test_time`, `response_time`, `base_url`, `other`, `balance`, `balance_updated_time`, `models`, `group`, `used_quota`, `model_mapping`, `status_code_mapping`, `priority`, `auto_ban`, `other_info`, `tag`, `setting`, `param_override`) VALUES
(1, 3, 'test', '', '', 1, 'az渠道', 0, 1745121022, 1745121045, 1212, 'https://inapi.openai.azure.com', '2025-01-01-preview', 0, 0, 'gpt-4-1106-preview', 'default', 0, '{\n  \"gpt-4-1106-preview\": \"gpt-4\"\n}', '', 0, 1, '', '', NULL, NULL);

INSERT INTO `options` (`key`, `value`) VALUES
('CheckSensitiveEnabled', 'false'),
('CheckSensitiveOnPromptEnabled', 'false'),
('DataExportEnabled', 'false'),
('DemoSiteEnabled', 'false'),
('LogConsumeEnabled', 'false'),
('RetryTimes', '3'),
('SelfUseModeEnabled', 'true');
EOF

echo "✅ 数据库初始化完成"
echo "✅ MySQL 密码已保存在 /home/ubuntu/data/new-api/mysql_credentials.txt"
echo "⚠️ 请妥善保管密码文件，建议记录后删除"

# 检查服务状态
echo "检查服务状态..."
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ new-api 服务运行正常"
else
    echo "⚠️ new-api 服务可能未正常运行，请检查日志"
fi
