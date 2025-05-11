#!/bin/bash

# 设置错误处理
set -e
trap 'echo "发生错误，脚本终止"; exit 1' ERR

# 获取当前订阅信息
echo "获取当前订阅信息..."
current_subscription=$(az account show --query id -o tsv)
echo "当前使用的订阅ID: $current_subscription"

# 设置默认值
location="eastus"
resource_group="new-api-rg-$(date +%Y%m%d)"
aci_name="new-api-$(date +%Y%m%d)"

echo "使用默认配置："
echo "区域: $location"
echo "资源组: $resource_group"
echo "ACI实例名称: $aci_name"

# 创建资源组
echo "创建资源组..."
az group create \
    --name "$resource_group" \
    --location "$location"

# 生成随机密码和令牌
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 20)
MYSQL_DATABASE=oneapi
MYSQL_USER=oneapi
MYSQL_PASSWORD=$(openssl rand -base64 20)
ADMIN_PASSWORD=$(openssl rand -base64 12)
ADMIN_TOKEN=$(openssl rand -base64 48)

# 创建Azure文件共享用于持久化存储
echo "创建Azure文件共享..."
storage_account_name="${aci_name//-/}storage"
file_share_name="newapi"

# 确保存储账户名称合法（小写字母和数字，3-24个字符）
storage_account_name=$(echo "$storage_account_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
if [ ${#storage_account_name} -gt 24 ]; then
    storage_account_name=${storage_account_name:0:24}
fi

echo "使用存储账户名: $storage_account_name"

# 创建存储账户
echo "创建存储账户..."
az storage account create \
    --name "$storage_account_name" \
    --resource-group "$resource_group" \
    --location "$location" \
    --sku Standard_LRS \
    --kind StorageV2

# 等待存储账户创建完成
echo "等待存储账户创建完成..."
sleep 10

# 获取存储账户密钥
echo "获取存储账户密钥..."
storage_key=$(az storage account keys list \
    --account-name "$storage_account_name" \
    --resource-group "$resource_group" \
    --query '[0].value' -o tsv)

if [ -z "$storage_key" ]; then
    echo "❌ 获取存储账户密钥失败"
    exit 1
fi

# 创建文件共享
echo "创建文件共享..."
az storage share create \
    --name "$file_share_name" \
    --account-name "$storage_account_name" \
    --account-key "$storage_key"

# 创建ACI实例
echo "正在创建ACI实例..."
az container create \
    --resource-group "$resource_group" \
    --name "$aci_name" \
    --image lfnull/new-api-magic:v0.6.6.3 \
    --cpu 2 \
    --memory 4 \
    --ports 80 \
    --dns-name-label "$aci_name" \
    --environment-variables \
        SQL_DSN="${MYSQL_USER}:${MYSQL_PASSWORD}@tcp(mysql:3306)/${MYSQL_DATABASE}" \
        TZ="Asia/Shanghai" \
        GENERATE_DEFAULT_TOKEN="true" \
        MODEL_MAPPING="gpt-4-turbo-2024-04-09:gpt-4" \
    --azure-file-volume-account-name "$storage_account_name" \
    --azure-file-volume-account-key "$storage_key" \
    --azure-file-volume-share-name "$file_share_name" \
    --azure-file-volume-mount-path "/data"

# 保存凭据信息
cat > aci_credentials.txt << EOF
MySQL Root Password: ${MYSQL_ROOT_PASSWORD}
MySQL Database: ${MYSQL_DATABASE}
MySQL User: ${MYSQL_USER}
MySQL Password: ${MYSQL_PASSWORD}
Admin Username: az-root
Admin Password: ${ADMIN_PASSWORD}
Admin Token: ${ADMIN_TOKEN}
Storage Account: ${storage_account_name}
File Share: ${file_share_name}
Resource Group: ${resource_group}
Location: ${location}
ACI Name: ${aci_name}
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
