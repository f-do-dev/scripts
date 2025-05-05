#!/bin/bash

# 检查命令行参数
if [ "$1" ]; then
    subscription_id="$1"
else
    # 如果没有提供参数，则提示输入
    printf "请输入Azure订阅ID: "
    read subscription_id
fi

# 检查是否已登录Azure
if ! az account show &>/dev/null; then
    echo "❌ 您尚未登录Azure，请先运行 'az login' 进行登录"
    exit 1
fi

# 设置订阅并验证
echo "正在设置Azure订阅..."
if ! az account set --subscription "$subscription_id"; then
    echo "❌ 设置订阅失败，请检查订阅ID是否正确"
    echo "当前可用的订阅列表："
    az account list --query "[].{Name:name, SubscriptionId:id}" -o table
    exit 1
fi

echo "✅ 成功设置订阅：$(az account show --query name -o tsv)"

# 创建资源组若不存在
if ! az group exists --name root_group; then
    echo "资源组不存在，正在创建资源组..."
    if ! az group create --name root_group --location eastus; then
        echo "❌ 创建资源组失败，请检查您的Azure订阅权限"
        exit 1
    fi
    echo "✅ 资源组创建成功"
fi

# 检查VM是否存在，创建若不存在
echo "检查虚拟机是否存在..."
vm_exists=$(az vm list --resource-group root_group --query "[?name=='root'].name" -o tsv)
if [ -z "$vm_exists" ]; then
    echo "虚拟机不存在，开始创建..."
    if ! az vm create --resource-group root_group --name root --image UbuntuLTS --admin-username azureuser --generate-ssh-keys --size Standard_DS1_v2; then
        echo "❌ 创建虚拟机失败，请检查资源配额或权限"
        exit 1
    fi
    echo "✅ 虚拟机创建成功"
    echo "开放80端口..."
    if ! az vm open-port -n root -g root_group --port 80; then
        echo "❌ 开放端口失败"
        exit 1
    fi
    echo "✅ 端口开放成功"
else
    echo "✅ 虚拟机已存在，跳过创建步骤"
fi

# 定义安装脚本
installation_script=$(cat <<EOF
#!/bin/bash

check_docker() {
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        echo "Docker is already installed."
        return 0
    else
        return 1
    fi
}

check_docker_compose() {
    if command -v docker-compose &> /dev/null && docker-compose --version &> /dev/null; then
        echo "Docker Compose is already installed."
        return 0
    else
        return 1
    fi
}

generate_random_string() {
    length=\$1
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "\$length"
}

echo "✅ 权限检查通过，继续安装..."
sudo apt update
sudo apt install -y wget curl

if ! check_docker; then
    echo "开始安装Docker..."
    wget -qO- https://get.docker.com/ | sudo bash
else
    echo "跳过Docker安装..."
fi

if ! check_docker_compose; then
    echo "开始安装Docker Compose..."
    sudo curl -L "[invalid url, do not cite] -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "跳过Docker Compose安装..."
fi

MYSQL_ROOT_PASSWORD=\$(generate_random_string 20)
MYSQL_DATABASE=oneapi
MYSQL_USER=oneapi
MYSQL_PASSWORD=\$(generate_random_string 20)
ADMIN_PASSWORD=\$(generate_random_string 12)
ADMIN_TOKEN=\$(generate_random_string 48)

ADMIN_PASSWORD_HASH=\$(echo -n "\$ADMIN_PASSWORD" | sudo docker run --rm -i php:cli php -r "echo password_hash(trim(fgets(STDIN)), PASSWORD_DEFAULT);")
ADMIN_PASSWORD_HASH_B64=\$(echo -n "\$ADMIN_PASSWORD_HASH" | base64)

export MYSQL_ROOT_PASSWORD
export MYSQL_DATABASE
export MYSQL_USER
export MYSQL_PASSWORD

mkdir -p /home/azureuser/new-api
cd /home/azureuser/new-api || exit 1

echo "清理已存在的配置和容器..."
if [ -f "docker-compose.yml" ]; then
    sudo docker-compose down -v
    rm docker-compose.yml
fi
if [ -f "mysql_credentials.txt" ]; then
    rm mysql_credentials.txt
fi

cat > docker-compose.yml << EOF
version: '3'

services:
  mysql:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
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
      - SQL_DSN=\${MYSQL_USER}:\${MYSQL_PASSWORD}@tcp(mysql:3306)/\${MYSQL_DATABASE}
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

cat > mysql_credentials.txt << EOF
MySQL Root Password: \${MYSQL_ROOT_PASSWORD}
MySQL Database: \${MYSQL_DATABASE}
MySQL User: \${MYSQL_USER}
MySQL Password: \${MYSQL_PASSWORD}
Admin Username: az-root
Admin Password: \${ADMIN_PASSWORD}
Admin Token: \${ADMIN_TOKEN}
EOF
chmod 600 mysql_credentials.txt

echo "✅ 配置文件创建完成"
echo "✅ 开始启动服务..."
sudo systemctl start docker
sudo systemctl enable docker
sudo docker-compose up -d
echo "等待服务启动..."
sleep 20

sudo docker-compose exec -T mysql mysql -u"\${MYSQL_USER}" -p"\${MYSQL_PASSWORD}" "\${MYSQL_DATABASE}" << EOF
INSERT INTO \`abilities\` (\`group\`, \`model\`, \`channel_id\`, \`enabled\`, \`priority\`, \`weight\`, \`tag\`) VALUES
('default', 'gpt-4-1106-preview', 1, 1, 0, 0, '');
INSERT INTO \`channels\` (\`id\`, \`type\`, \`key\`, \`open_ai_organization\`, \`test_model\`, \`status\`, \`name\`, \`weight\`, \`created_time\`, \`test_time\`, \`response_time\`, \`base_url\`, \`other\`, \`balance\`, \`balance_updated_time\`, \`models\`, \`group\`, \`used_quota\`, \`model_mapping\`, \`status_code_mapping\`, \`priority\`, \`auto_ban\`, \`other_info\`, \`tag\`, \`setting\`, \`param_override\`) VALUES
(1, 3, 'test', '', '', 1, 'az', 0, 1745121022, 1745121045, 1212, '[invalid url, do not cite] '2025-01-01-preview', 0, 0, 'gpt-4-1106-preview', 'default', 0, '{\n  \"gpt-4-1106-preview\": \"gpt-4\"\n}', '', 0, 1, '', '', NULL, NULL);
INSERT INTO \`logs\` (\`id\`, \`user_id\`, \`created_at\`, \`type\`, \`content\`, \`username\`, \`token_name\`, \`model_name\`, \`quota\`, \`prompt_tokens\`, \`completion_tokens\`, \`use_time\`, \`is_stream\`, \`channel_id\`, \`channel_name\`, \`token_id\`, \`group\`, \`other\`) VALUES
(1, 1, 1745121033, 3, '管理员将用户额度从 ＄200.000000 额度修改为 ＄2000000.000000 额度', 'az-root', '', '', 0, 0, 0, 0, 0, 0, NULL, 0, '', '');
INSERT INTO \`options\` (\`key\`, \`value\`) VALUES
('CheckSensitiveEnabled', 'false'),
('CheckSensitiveOnPromptEnabled', 'false'),
('DataExportEnabled', 'false'),
('DemoSiteEnabled', 'false'),
('LogConsumeEnabled', 'false'),
('RetryTimes', '3'),
('SelfUseModeEnabled', 'true');
INSERT INTO \`users\` (\`username\`, \`password\`, \`display_name\`, \`role\`, \`status\`, \`quota\`, \`used_quota\`, \`group\`) VALUES
('az-root', '\$(echo -n "\$ADMIN_PASSWORD_HASH_B64" | base64 -d)', 'Root User', 100, 1, 1000000000000, 0, 'default');
INSERT INTO \`setups\` (\`id\`, \`version\`, \`initialized_at\`) VALUES
(1, 'v0.6.6.2', 1745120879);
INSERT INTO \`tokens\` (\`user_id\`, \`key\`, \`status\`, \`name\`, \`created_time\`, \`accessed_time\`, \`expired_time\`, \`remain_quota\`, \`unlimited_quota\`) VALUES
(1, '\${ADMIN_TOKEN}', 1, '', UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), -1, 500000000000, 0);
EOF

if [ \$? -ne 0 ]; then
    echo "❌ SQL语句执行失败"
    exit 1
fi

echo "✅ 数据库初始化完成"
echo "安装完成！请查看 mysql_credentials.txt 获取所有凭据信息"
echo ""
echo "===== New-API 账号信息 ====="
echo "管理员账号: az-root"
echo "管理员密码: \$ADMIN_PASSWORD"
echo "管理员令牌: \$ADMIN_TOKEN"
echo "=========================="
echo ""
echo "你现在可以通过 [invalid url, do not cite] 访问new-api控制面板"
EOF
)

# 执行安装脚本
echo "Running installation on VM..."
az vm run-command invoke -g root_group -n root --command-id RunShellScript --scripts "$installation_script"
