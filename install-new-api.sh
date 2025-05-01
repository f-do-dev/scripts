#!/bin/bash

# 检查是否有sudo权限
check_sudo() {
    if sudo -n true 2>/dev/null; then
        echo "✅ 已具有sudo权限"
        return 0
    else
        echo "⚠️ 未检测到sudo权限，尝试通过Azure CLI获取权限..."
        return 1
    fi
}

# 通过Azure CLI获取权限
get_azure_access() {
    # 检查是否安装了Azure CLI
    if ! command -v az &> /dev/null; then
        echo "❌ 未安装Azure CLI，请先安装Azure CLI"
        exit 1
    fi

    # 提示用户输入订阅ID
    subscription_id=""
    while true; do
        printf "请输入Azure订阅ID: "
        IFS= read -r subscription_id </dev/tty
        
        if [ -n "$subscription_id" ]; then
            break
        else
            echo "❌ 订阅ID不能为空，请重新输入"
        fi
    done

    echo "正在通过Azure CLI获取root权限..."
    az ssh vm --resource-group root_group --vm-name root --subscription "$subscription_id"
    
    # 再次检查sudo权限
    if ! check_sudo; then
        echo "❌ 获取sudo权限失败"
        exit 1
    fi
}

# 检查Docker是否已安装
check_docker() {
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        echo "检测到Docker已安装:"
        docker --version
        read -p "是否重新安装Docker？[y/N] " choice
        case "$choice" in 
            y|Y ) return 1 ;;
            * ) return 0 ;;
        esac
    else
        return 1
    fi
}

# 检查Docker Compose是否已安装
check_docker_compose() {
    if command -v docker-compose &> /dev/null && docker-compose --version &> /dev/null; then
        echo "检测到Docker Compose已安装:"
        docker-compose --version
        read -p "是否重新安装Docker Compose？[y/N] " choice
        case "$choice" in 
            y|Y ) return 1 ;;
            * ) return 0 ;;
        esac
    else
        return 1
    fi
}

# 主程序开始
echo "开始检查权限..."
if ! check_sudo; then
    get_azure_access
fi

# 更新软件包索引
sudo apt update

# 安装必要的软件包
sudo apt install -y wget curl

# 检查并安装Docker
if ! check_docker; then
    echo "开始安装Docker..."
    wget -qO- https://get.docker.com/ | sudo bash
else
    echo "跳过Docker安装..."
fi

# 检查并安装Docker Compose
if ! check_docker_compose; then
    echo "开始安装Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "跳过Docker Compose安装..."
fi

# 创建项目目录
mkdir -p /home/ubuntu/new-api
cd /home/ubuntu/new-api

# 生成随机密码
MYSQL_ROOT_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)
MYSQL_DATABASE=oneapi
MYSQL_USER=oneapi
MYSQL_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)

# 创建 docker-compose.yml
cat > docker-compose.yml << EOF
version: '3'

services:
  mysql:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p\${MYSQL_ROOT_PASSWORD}"]
      interval: 5s
      timeout: 5s
      retries: 10

  new-api:
    image: lfnull/new-api-magic:v0.6.6.3
    restart: always
    ports:
      - "80:3000"
    environment:
      - SQL_DSN=${MYSQL_USER}:${MYSQL_PASSWORD}@tcp(mysql:3306)/${MYSQL_DATABASE}
      - TZ=Asia/Shanghai
      - GENERATE_DEFAULT_TOKEN=true
      - MODEL_MAPPING=gpt-4-turbo-2024-04-09:gpt-4
    volumes:
      - new_api_data:/data
    depends_on:
      mysql:
        condition: service_healthy

volumes:
  mysql_data:
  new_api_data:
EOF

# 保存数据库凭据
cat > mysql_credentials.txt << EOF
MySQL Root Password: ${MYSQL_ROOT_PASSWORD}
MySQL Database: ${MYSQL_DATABASE}
MySQL User: ${MYSQL_USER}
MySQL Password: ${MYSQL_PASSWORD}
EOF
chmod 600 mysql_credentials.txt

echo "✅ 配置文件创建完成"
echo "✅ 开始启动服务..."

# 启动服务
sudo docker-compose up -d

# 等待服务启动
echo "等待服务启动..."
sleep 20

# 初始化数据库
echo "开始执行数据库初始化..."
sudo docker-compose exec -T mysql mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} << 'EOF'
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
echo "✅ MySQL 凭据已保存在 mysql_credentials.txt"
echo "⚠️ 请妥善保管凭据文件，建议记录后删除"

# 检查服务状态
echo "检查服务状态..."
if curl -s http://localhost:80 > /dev/null; then
    echo "✅ new-api 服务运行正常"
else
    echo "⚠️ new-api 服务可能未正常运行，请检查日志："
    echo "使用 'docker-compose logs new-api' 查看日志"
fi
