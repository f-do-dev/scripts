#!/bin/bash

# 设置错误处理
set -e
trap 'echo "发生错误，脚本终止"; exit 1' ERR

# 确保用户已登录
echo "正在检查Azure登录状态..."
if ! az account show &>/dev/null; then
    echo "您尚未登录Azure，正在尝试登录..."
    az login
fi

# 获取当前订阅信息
echo "获取当前订阅信息..."
current_subscription=$(az account show --query id -o tsv)
subscription_name=$(az account show --query name -o tsv)
echo "当前使用的订阅: $subscription_name ($current_subscription)"

# 检查并注册Microsoft.ContainerInstance资源提供程序
echo "检查Microsoft.ContainerInstance资源提供程序注册状态..."
registration_state=$(az provider show --namespace Microsoft.ContainerInstance --query "registrationState" -o tsv)

if [ "$registration_state" != "Registered" ]; then
    echo "正在注册Microsoft.ContainerInstance资源提供程序..."
    az provider register --namespace Microsoft.ContainerInstance
    
    echo "等待资源提供程序注册完成..."
    while [ "$(az provider show --namespace Microsoft.ContainerInstance --query "registrationState" -o tsv)" != "Registered" ]; do
        echo -n "."
        sleep 10
    done
    echo " 完成!"
else
    echo "Microsoft.ContainerInstance资源提供程序已注册"
fi

# 检查并注册Microsoft.ContainerRegistry资源提供程序
echo "检查Microsoft.ContainerRegistry资源提供程序注册状态..."
registration_state=$(az provider show --namespace Microsoft.ContainerRegistry --query "registrationState" -o tsv)

if [ "$registration_state" != "Registered" ]; then
    echo "正在注册Microsoft.ContainerRegistry资源提供程序..."
    az provider register --namespace Microsoft.ContainerRegistry
    
    echo "等待资源提供程序注册完成..."
    while [ "$(az provider show --namespace Microsoft.ContainerRegistry --query "registrationState" -o tsv)" != "Registered" ]; do
        echo -n "."
        sleep 10
    done
    echo " 完成!"
else
    echo "Microsoft.ContainerRegistry资源提供程序已注册"
fi

# 设置默认值
location="eastus"
current_date=$(date +%Y%m%d%H%M%S)
resource_group="new-api-rg-$current_date"
aci_name="new-api-$current_date"
acr_name="newapiacr$current_date"

echo "使用默认配置："
echo "区域: $location"
echo "资源组: $resource_group"
echo "ACI实例名称: $aci_name"
echo "ACR名称: $acr_name"

# 创建资源组
echo "创建资源组..."
az group create \
    --name "$resource_group" \
    --location "$location"

# 确保ACR名称符合要求（小写字母和数字，5-50个字符）
acr_name=$(echo "$acr_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
if [ ${#acr_name} -gt 50 ]; then
    acr_name=${acr_name:0:50}
fi
echo "使用ACR名称: $acr_name"

# 创建Azure Container Registry
echo "创建Azure Container Registry..."
az acr create \
    --resource-group "$resource_group" \
    --name "$acr_name" \
    --sku Basic \
    --admin-enabled true

# 导入容器镜像
echo "导入容器镜像到ACR..."
az acr import \
    --name "$acr_name" \
    --source docker.io/lfnull/new-api-magic:v0.6.6.3 \
    --image new-api-magic:v0.6.6.3

# 获取ACR登录凭据
echo "获取ACR登录凭据..."
acr_username=$(az acr credential show --name "$acr_name" --query "username" -o tsv)
acr_password=$(az acr credential show --name "$acr_name" --query "passwords[0].value" -o tsv)
acr_server=$(az acr show --name "$acr_name" --query "loginServer" -o tsv)

# 生成随机密码和令牌
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 20)
MYSQL_DATABASE=oneapi
MYSQL_USER=oneapi
MYSQL_PASSWORD=$(openssl rand -base64 20)
ADMIN_PASSWORD=$(openssl rand -base64 12)
ADMIN_TOKEN=$(openssl rand -base64 48)

# 直接部署ACI，不使用存储账户
echo "正在创建ACI实例（不使用持久化存储）..."
az container create \
    --resource-group "$resource_group" \
    --name "$aci_name" \
    --image "${acr_server}/new-api-magic:v0.6.6.3" \
    --registry-login-server "$acr_server" \
    --registry-username "$acr_username" \
    --registry-password "$acr_password" \
    --os-type Linux \
    --cpu 2 \
    --memory 4 \
    --ports 80 \
    --dns-name-label "$aci_name" \
    --environment-variables \
        SQL_DSN="${MYSQL_USER}:${MYSQL_PASSWORD}@tcp(mysql:3306)/${MYSQL_DATABASE}" \
        TZ="Asia/Shanghai" \
        GENERATE_DEFAULT_TOKEN="true" \
        MODEL_MAPPING="gpt-4-turbo-2024-04-09:gpt-4"

# 保存凭据信息
cat > aci_credentials.txt << EOF
MySQL Root Password: ${MYSQL_ROOT_PASSWORD}
MySQL Database: ${MYSQL_DATABASE}
MySQL User: ${MYSQL_USER}
MySQL Password: ${MYSQL_PASSWORD}
Admin Username: az-root
Admin Password: ${ADMIN_PASSWORD}
Admin Token: ${ADMIN_TOKEN}
Resource Group: ${resource_group}
Location: ${location}
ACI Name: ${aci_name}
ACR Name: ${acr_name}
Subscription: ${current_subscription}

注意：此部署没有使用持久化存储，如果容器重启，数据将丢失
EOF

chmod 600 aci_credentials.txt

echo "✅ 部署完成！"
echo "ACI实例名称: ${aci_name}"
echo "资源组: ${resource_group}"
echo "请查看 aci_credentials.txt 获取所有凭据信息"

# 获取ACI的公共IP地址和FQDN
aci_ip=$(az container show \
    --resource-group "$resource_group" \
    --name "$aci_name" \
    --query ipAddress.ip -o tsv 2>/dev/null || echo "无法获取IP地址")

aci_fqdn=$(az container show \
    --resource-group "$resource_group" \
    --name "$aci_name" \
    --query ipAddress.fqdn -o tsv 2>/dev/null || echo "无法获取FQDN")

echo ""
echo "===== New-API 账号信息 ====="
echo "管理员账号: az-root"
echo "管理员密码: ${ADMIN_PASSWORD}"
echo "管理员令牌: ${ADMIN_TOKEN}"
echo "=========================="
echo ""
if [ "$aci_ip" != "无法获取IP地址" ]; then
    echo "你现在可以通过 http://${aci_ip} 访问new-api控制面板"
fi
if [ "$aci_fqdn" != "无法获取FQDN" ]; then
    echo "或者通过 http://${aci_fqdn} 访问"
fi

echo ""
echo "注意：这个ACI实例没有使用持久化存储，如果容器重启，数据将丢失"
