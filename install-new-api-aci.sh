#!/bin/bash

# 创建Azure容器实例(ACI)
create_azure_aci() {
    echo "开始创建Azure容器实例(ACI)..."
    
    # 设置变量
    RESOURCE_GROUP="aci-group"
    LOCATION="eastus"  # 可以根据需要修改位置
    ACI_NAME="new-api-aci"
    
    # 生成随机密码和令牌
    MYSQL_ROOT_PASSWORD=$(generate_random_string 20)
    MYSQL_DATABASE=oneapi
    MYSQL_USER=oneapi
    MYSQL_PASSWORD=$(generate_random_string 20)
    ADMIN_PASSWORD=$(generate_random_string 12)
    ADMIN_TOKEN=$(generate_random_string 48)
    
    # 注册必要的资源提供程序
    echo "正在注册必要的资源提供程序..."
    az provider register --namespace Microsoft.ContainerInstance
    az provider register --namespace Microsoft.Storage

    # 等待注册完成
    echo "等待资源提供程序注册完成..."
    az provider show -n Microsoft.ContainerInstance -o table
    az provider show -n Microsoft.Storage -o table

    # 创建资源组
    echo "创建资源组..."
    az group create --name $RESOURCE_GROUP --location $LOCATION

    # 创建存储账户用于持久化数据
    STORAGE_ACCOUNT_NAME="newapi$(generate_random_string 8 | tr '[:upper:]' '[:lower:]')"
    echo "创建存储账户 $STORAGE_ACCOUNT_NAME..."
    az storage account create \
        --resource-group $RESOURCE_GROUP \
        --name $STORAGE_ACCOUNT_NAME \
        --location $LOCATION \
        --sku Standard_LRS
    
    # 获取存储账户连接字符串
    STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
        --resource-group $RESOURCE_GROUP \
        --name $STORAGE_ACCOUNT_NAME \
        --query connectionString \
        --output tsv)
    
    # 创建文件共享
    SHARE_NAME="newapishare"
    echo "创建文件共享 $SHARE_NAME..."
    az storage share create \
        --name $SHARE_NAME \
        --connection-string $STORAGE_CONNECTION_STRING
    
    # 创建MySQL容器组
    echo "创建MySQL容器组..."
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name "mysql-$ACI_NAME" \
        --image mysql:8.0 \
        --dns-name-label "mysql-$ACI_NAME" \
        --ports 3306 \
        --cpu 1 \
        --memory 1.5 \
        --restart-policy Always \
        --os-type Linux \
        --environment-variables \
            MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
            MYSQL_DATABASE=$MYSQL_DATABASE \
            MYSQL_USER=$MYSQL_USER \
            MYSQL_PASSWORD=$MYSQL_PASSWORD \
        --azure-file-volume-account-name $STORAGE_ACCOUNT_NAME \
        --azure-file-volume-account-key "$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" --output tsv)" \
        --azure-file-volume-share-name $SHARE_NAME \
        --azure-file-volume-mount-path /var/lib/mysql
    
    # 检查MySQL容器是否创建成功
    if [ $? -ne 0 ]; then
        echo "❌ MySQL容器创建失败"
        exit 1
    fi
    
    # 获取MySQL容器的FQDN
    MYSQL_FQDN=$(az container show \
        --resource-group $RESOURCE_GROUP \
        --name "mysql-$ACI_NAME" \
        --query ipAddress.fqdn \
        --output tsv)

    # 如果FQDN不存在，使用IP地址
    if [ -z "$MYSQL_FQDN" ]; then
        MYSQL_FQDN=$(az container show \
            --resource-group $RESOURCE_GROUP \
            --name "mysql-$ACI_NAME" \
            --query ipAddress.ip \
            --output tsv)
    fi
    
    # 等待MySQL启动完成
    echo "等待MySQL启动完成，FQDN: $MYSQL_FQDN"
    sleep 60
    
    # 创建new-api容器组
    echo "创建new-api容器组..."
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name $ACI_NAME \
        --image lfnull/new-api-magic:v0.6.6.3 \
        --dns-name-label $ACI_NAME \
        --ports 3000 \
        --cpu 1 \
        --memory 1.5 \
        --restart-policy Always \
        --os-type Linux \
        --environment-variables \
            SQL_DSN="$MYSQL_USER:$MYSQL_PASSWORD@tcp($MYSQL_FQDN:3306)/$MYSQL_DATABASE" \
            TZ=Asia/Shanghai \
            GENERATE_DEFAULT_TOKEN=true \
            MODEL_MAPPING=gpt-4-turbo-2024-04-09:gpt-4 \
        --azure-file-volume-account-name $STORAGE_ACCOUNT_NAME \
        --azure-file-volume-account-key "$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" --output tsv)" \
        --azure-file-volume-share-name $SHARE_NAME \
        --azure-file-volume-mount-path /data
        
    # 检查New-API容器是否创建成功
    if [ $? -ne 0 ]; then
        echo "❌ New-API容器创建失败"
        exit 1
    fi
    
    # 获取new-api容器的FQDN
    NEW_API_FQDN=$(az container show \
        --resource-group $RESOURCE_GROUP \
        --name $ACI_NAME \
        --query ipAddress.fqdn \
        --output tsv)
    
    # 获取new-api容器的IP地址
    NEW_API_IP=$(az container show \
        --resource-group $RESOURCE_GROUP \
        --name $ACI_NAME \
        --query ipAddress.ip \
        --output tsv)
    
    # 等待new-api启动完成
    echo "等待new-api启动完成..."
    sleep 30
    
    # 初始化数据库
    # 使用临时容器运行MySQL命令
    echo "初始化数据库..."
    
    # 生成管理员密码哈希
    echo "生成管理员密码哈希..."
    TEMP_HASH_CONTAINER="temp-php-hash"
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name $TEMP_HASH_CONTAINER \
        --image php:cli \
        --restart-policy Never \
        --os-type Linux \
        --command-line "php -r \"echo password_hash('$ADMIN_PASSWORD', PASSWORD_DEFAULT);\"" \
        --output tsv
    
    # 等待临时容器完成
    echo "等待哈希生成完成..."
    sleep 15
    
    # 检查容器状态，确保已完成
    CONTAINER_STATE=""
    while [ "$CONTAINER_STATE" != "Terminated" ]; do
        CONTAINER_STATE=$(az container show \
            --resource-group $RESOURCE_GROUP \
            --name $TEMP_HASH_CONTAINER \
            --query "containers[0].instanceView.currentState.state" \
            --output tsv)
        
        if [ "$CONTAINER_STATE" != "Terminated" ]; then
            echo "等待容器完成任务，当前状态: $CONTAINER_STATE"
            sleep 5
        fi
    done
    
    # 获取密码哈希输出
    ADMIN_PASSWORD_HASH=$(az container logs \
        --resource-group $RESOURCE_GROUP \
        --name $TEMP_HASH_CONTAINER \
        --output tsv)
    
    echo "密码哈希生成完成"
    
    # 删除临时容器
    echo "删除临时哈希容器..."
    az container delete \
        --resource-group $RESOURCE_GROUP \
        --name $TEMP_HASH_CONTAINER \
        --yes
    
    # 创建临时SQL文件
    echo "创建SQL初始化命令..."
    TMP_SQL_FILE=$(mktemp)
    cat > $TMP_SQL_FILE << EOF
INSERT INTO \`abilities\` (\`group\`, \`model\`, \`channel_id\`, \`enabled\`, \`priority\`, \`weight\`, \`tag\`) VALUES
('default', 'gpt-4-1106-preview', 1, 1, 0, 0, '');

INSERT INTO \`channels\` (\`id\`, \`type\`, \`key\`, \`open_ai_organization\`, \`test_model\`, \`status\`, \`name\`, \`weight\`, \`created_time\`, \`test_time\`, \`response_time\`, \`base_url\`, \`other\`, \`balance\`, \`balance_updated_time\`, \`models\`, \`group\`, \`used_quota\`, \`model_mapping\`, \`status_code_mapping\`, \`priority\`, \`auto_ban\`, \`other_info\`, \`tag\`, \`setting\`, \`param_override\`) VALUES
(1, 3, 'test', '', '', 1, 'az', 0, 1745121022, 1745121045, 1212, 'https://inapi.openai.azure.com', '2025-01-01-preview', 0, 0, 'gpt-4-1106-preview', 'default', 0, '{\n  \"gpt-4-1106-preview\": \"gpt-4\"\n}', '', 0, 1, '', '', NULL, NULL);

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
('az-root', '$ADMIN_PASSWORD_HASH', 'Root User', 100, 1, 1000000000000, 0, 'default');

INSERT INTO \`setups\` (\`id\`, \`version\`, \`initialized_at\`) VALUES
(1, 'v0.6.6.2', 1745120879);

INSERT INTO \`tokens\` (\`user_id\`, \`key\`, \`status\`, \`name\`, \`created_time\`, \`accessed_time\`, \`expired_time\`, \`remain_quota\`, \`unlimited_quota\`) VALUES
(1, '$ADMIN_TOKEN', 1, '', UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), -1, 500000000000, 0);
EOF

    # 读取SQL命令
    SQL_COMMAND=$(cat $TMP_SQL_FILE)
    
    # 创建临时容器执行SQL
    echo "创建临时MySQL容器执行SQL初始化..."
    TEMP_MYSQL_CONTAINER="temp-mysql-init"
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name $TEMP_MYSQL_CONTAINER \
        --image mysql:8.0 \
        --restart-policy Never \
        --os-type Linux \
        --command-line "mysql -h$MYSQL_FQDN -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e \"$SQL_COMMAND\"" \
        --output tsv
    
    # 等待临时容器完成
    echo "等待数据库初始化完成..."
    sleep 30
    
    # 检查容器状态，确保已完成
    CONTAINER_STATE=""
    while [ "$CONTAINER_STATE" != "Terminated" ]; do
        CONTAINER_STATE=$(az container show \
            --resource-group $RESOURCE_GROUP \
            --name $TEMP_MYSQL_CONTAINER \
            --query "containers[0].instanceView.currentState.state" \
            --output tsv 2>/dev/null)
        
        if [ "$CONTAINER_STATE" != "Terminated" ]; then
            echo "等待容器完成任务，当前状态: $CONTAINER_STATE"
            sleep 5
        fi
    done
    
    # 检查容器执行结果
    EXIT_CODE=$(az container show \
        --resource-group $RESOURCE_GROUP \
        --name $TEMP_MYSQL_CONTAINER \
        --query "containers[0].instanceView.currentState.exitCode" \
        --output tsv)
    
    if [ "$EXIT_CODE" -ne 0 ]; then
        echo "❌ 数据库初始化失败，查看日志:"
        az container logs \
            --resource-group $RESOURCE_GROUP \
            --name $TEMP_MYSQL_CONTAINER
        echo "退出安装..."
        exit 1
    else
        echo "✅ 数据库初始化成功!"
    fi
    
    # 删除临时容器
    echo "删除临时MySQL容器..."
    az container delete \
        --resource-group $RESOURCE_GROUP \
        --name $TEMP_MYSQL_CONTAINER \
        --yes
    
    # 删除临时SQL文件
    rm $TMP_SQL_FILE
    
    # 保存凭据信息
    cat > new-api-credentials.txt << EOF
Azure 资源组: ${RESOURCE_GROUP}
ACI 名称: ${ACI_NAME}
MySQL ACI 名称: mysql-${ACI_NAME}
MySQL 主机名: ${MYSQL_FQDN}
MySQL Root 密码: ${MYSQL_ROOT_PASSWORD}
MySQL 数据库: ${MYSQL_DATABASE}
MySQL 用户: ${MYSQL_USER}
MySQL 密码: ${MYSQL_PASSWORD}
存储账户: ${STORAGE_ACCOUNT_NAME}
文件共享: ${SHARE_NAME}
New-API 管理员账号: az-root
New-API 管理员密码: ${ADMIN_PASSWORD}
New-API 管理员令牌: ${ADMIN_TOKEN}
New-API URL: http://${NEW_API_FQDN}:3000
New-API IP: ${NEW_API_IP}
EOF
    chmod 600 new-api-credentials.txt
    
    echo "✅ Azure容器实例(ACI)创建成功！"
    echo "✅ 数据库初始化完成"
    echo "安装完成！请查看 new-api-credentials.txt 获取所有凭据信息"
    
    # 打印new-api的账号和密码信息
    echo ""
    echo "===== New-API 账号信息 ====="
    echo "管理员账号: az-root"
    echo "管理员密码: ${ADMIN_PASSWORD}"
    echo "管理员令牌: ${ADMIN_TOKEN}"
    echo "=========================="
    echo ""
    echo "你现在可以通过 http://${NEW_API_FQDN}:3000 访问new-api控制面板"
}

# 检查Azure CLI是否已安装
check_azure_cli() {
    if command -v az &> /dev/null; then
        echo "✅ Azure CLI已安装"
        # 检查是否已登录
        if az account show &> /dev/null; then
            echo "✅ 已登录Azure账户"
            return 0
        else
            echo "⚠️ 未登录Azure账户，请先登录"
            az login
            if [ $? -ne 0 ]; then
                echo "❌ 登录失败"
                return 1
            fi
            echo "✅ 登录成功"
            return 0
        fi
    else
        echo "❌ 未安装Azure CLI，请先安装Azure CLI"
        return 1
    fi
}

# 生成随机字符串
generate_random_string() {
    length=$1
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

# 主程序开始
echo "开始检查Azure CLI..."
if ! check_azure_cli; then
    echo "❌ Azure CLI检查失败，退出安装"
    exit 1
fi

echo "✅ Azure CLI检查通过，继续安装..."

# 创建Azure容器实例
create_azure_aci

echo "安装完成！"
