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

# 列出并选择订阅
echo "列出可用的Azure订阅..."
az account list --output table

# 用户选择要使用的订阅
echo "请从上面的列表中选择要使用的订阅"
read -p "输入要使用的订阅ID: " subscription_id

# 如果用户输入了订阅ID，则设置为当前订阅
if [ -n "$subscription_id" ]; then
    echo "设置当前订阅为: $subscription_id"
    az account set --subscription "$subscription_id"
fi

# 获取当前订阅信息
echo "获取当前订阅信息..."
current_subscription=$(az account show --query id -o tsv)
subscription_name=$(az account show --query name -o tsv)
echo "当前使用的订阅: $subscription_name ($current_subscription)"

# 设置默认值
location="eastus"
current_date=$(date +%Y%m%d%H%M%S)
resource_group="new-api-rg-$current_date"
aci_name="new-api-$current_date"

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
storage_account_name="newapi${current_date}"
file_share_name="newapi"

# 确保存储账户名称合法（小写字母和数字，3-24个字符）
storage_account_name=$(echo "$storage_account_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
if [ ${#storage_account_name} -gt 24 ]; then
    storage_account_name=${storage_account_name:0:24}
fi

echo "使用存储账户名: $storage_account_name"

# 创建存储账户，添加重试机制
echo "创建存储账户..."
max_retries=3
retry_count=0
while [ $retry_count -lt $max_retries ]; do
    if az storage account create \
        --name "$storage_account_name" \
        --resource-group "$resource_group" \
        --location "$location" \
        --sku Standard_LRS \
        --kind StorageV2; then
        echo "存储账户创建成功！"
        break
    else
        retry_count=$((retry_count+1))
        if [ $retry_count -lt $max_retries ]; then
            echo "存储账户创建失败，尝试重新登录Azure..."
            az login
            echo "设置当前订阅..."
            az account set --subscription "$current_subscription"
            echo "重试第 $retry_count 次..."
            sleep 5
        else
            echo "最大重试次数已达到，脚本终止"
            exit 1
        fi
    fi
done

# 等待存储账户创建完成
echo "等待存储账户创建完成..."
sleep 15

# 获取存储账户连接字符串
echo "获取存储账户连接字符串..."
connection_string=$(az storage account show-connection-string \
    --name "$storage_account_name" \
    --resource-group "$resource_group" \
    --query connectionString \
    --output tsv)

if [ -z "$connection_string" ]; then
    echo "❌ 获取存储账户连接字符串失败"
    exit 1
fi

# 创建文件共享
echo "创建文件共享..."
az storage share create \
    --name "$file_share_name" \
    --connection-string "$connection_string"

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
Subscription: ${current_subscription}
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
