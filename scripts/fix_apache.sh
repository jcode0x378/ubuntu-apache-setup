#!/bin/bash
# Apache 修復腳本 - 用於診斷和解決 Apache 常見問題

echo "==== 開始 Apache 服務診斷和修復 ===="

# 確保腳本以 root 權限運行
if [ "$(id -u)" != "0" ]; then
   echo "此腳本需要 root 權限運行" 1>&2
   exit 1
fi

# 檢查 Apache 是否已安裝
if ! command -v apache2 &> /dev/null; then
    echo "錯誤：Apache 未安裝。正在安裝..."
    apt update
    apt install -y apache2
fi

# 檢查 Apache 服務狀態
echo "檢查 Apache 服務狀態..."
if systemctl is-active apache2 >/dev/null; then
    echo "Apache 服務狀態：運行中"
else
    echo "警告：Apache 服務未運行，嘗試啟動..."
    systemctl start apache2
    
    if ! systemctl is-active apache2 >/dev/null; then
        echo "錯誤：無法啟動 Apache 服務"
    else
        echo "Apache 服務已成功啟動"
    fi
fi

# 檢查 Apache 配置
echo "檢查 Apache 配置..."
apache2ctl configtest

# 檢查 ports.conf 文件
echo "檢查 ports.conf 配置..."
if [ -f /etc/apache2/ports.conf ]; then
    if ! grep -q "Listen 0.0.0.0:80" /etc/apache2/ports.conf; then
        echo "修正 ports.conf，確保監聽 IPv4..."
        cat > /etc/apache2/ports.conf << EOF
# 配置 Apache 明確監聽 IPv4 和 IPv6
Listen 0.0.0.0:80
Listen [::]:80

<IfModule ssl_module>
    Listen 0.0.0.0:443
    Listen [::]:443
</IfModule>
EOF
        echo "已更新 ports.conf 配置"
    else
        echo "ports.conf 配置正確"
    fi
else
    echo "警告：ports.conf 不存在，創建新文件..."
    cat > /etc/apache2/ports.conf << EOF
# 配置 Apache 明確監聽 IPv4 和 IPv6
Listen 0.0.0.0:80
Listen [::]:80

<IfModule ssl_module>
    Listen 0.0.0.0:443
    Listen [::]:443
</IfModule>
EOF
    echo "已創建 ports.conf 配置"
fi

# 檢查默認站點配置
echo "檢查默認站點配置..."
if [ -f /etc/apache2/sites-available/000-default.conf ]; then
    if ! grep -q "<VirtualHost 0.0.0.0:80>" /etc/apache2/sites-available/000-default.conf; then
        echo "修正默認站點配置，使用明確的 IPv4 和 IPv6 設定..."
        # 備份原始配置
        cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.backup
        
        # 獲取當前 DocumentRoot
        DOC_ROOT=$(grep -oP 'DocumentRoot\s+\K[^ ]+' /etc/apache2/sites-available/000-default.conf)
        if [ -z "$DOC_ROOT" ]; then
            DOC_ROOT="/var/www/html"
        fi
        
        # 創建新的配置
        cat > /etc/apache2/sites-available/000-default.conf << EOF
<VirtualHost 0.0.0.0:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $DOC_ROOT
    
    <Directory $DOC_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

<VirtualHost [::]:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $DOC_ROOT
    
    <Directory $DOC_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
        echo "已更新默認站點配置"
    else
        echo "默認站點配置正確"
    fi
else
    echo "警告：默認站點配置不存在，創建新配置..."
    cat > /etc/apache2/sites-available/000-default.conf << EOF
<VirtualHost 0.0.0.0:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

<VirtualHost [::]:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
    echo "已創建默認站點配置"
fi

# 修正 apache2.conf 中的目錄權限設定
echo "檢查 apache2.conf 中的目錄權限設定..."
if ! grep -q "<Directory /home/*/www>" /etc/apache2/apache2.conf; then
    echo "添加 /home 目錄的權限設定..."
    cat >> /etc/apache2/apache2.conf << EOF

# 允許訪問 /home 目錄中的網站
<Directory /home/*/www>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF
    echo "已更新 apache2.conf 配置"
fi

# 修正 DocumentRoot 目錄權限
echo "修正 DocumentRoot 目錄權限..."
DOC_ROOT=$(grep -oP 'DocumentRoot\s+\K[^ ]+' /etc/apache2/sites-available/000-default.conf | head -1)
if [ -z "$DOC_ROOT" ]; then
    DOC_ROOT="/var/www/html"
fi

echo "確保 $DOC_ROOT 目錄存在和權限正確..."
mkdir -p "$DOC_ROOT"
find "$DOC_ROOT" -type d -exec chmod 755 {} \;
find "$DOC_ROOT" -type f -exec chmod 644 {} \;
chown -R www-data:www-data "$DOC_ROOT"

# 檢查並啟用必要的模組
echo "檢查並啟用必要的模組..."
a2enmod rewrite
a2enmod ssl
a2enmod headers

# 創建測試頁面
echo "創建測試頁面..."
if [ ! -f "$DOC_ROOT/index.html" ] && [ ! -f "$DOC_ROOT/index.php" ]; then
    cat > "$DOC_ROOT/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Apache 修復成功</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 40px;
            color: #333;
        }
        h1 {
            color: #4CAF50;
        }
        .success {
            padding: 20px;
            background-color: #f9f9f9;
            border-left: 5px solid #4CAF50;
        }
    </style>
</head>
<body>
    <h1>Apache 服務已修復！</h1>
    <div class="success">
        <p>Apache 服務已經成功修復並重新啟動。</p>
        <p>如果您看到此頁面，表示您的 Apache 網頁伺服器正常運行。</p>
        <p>伺服器時間: $(date)</p>
        <p>伺服器 IP: $(hostname -I)</p>
    </div>
</body>
</html>
EOF
    echo "已創建測試頁面"
fi

# 檢查防火牆設定
echo "檢查防火牆設定..."
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "active"; then
        echo "防火牆已啟用，確保允許 HTTP 流量..."
        ufw allow 80/tcp
        ufw allow 443/tcp
    else
        echo "防火牆未啟用"
    fi
else
    echo "未安裝 ufw 防火牆"
fi

# 重啟 Apache 服務
echo "重啟 Apache 服務..."
systemctl restart apache2

# 驗證 Apache 服務狀態
if systemctl is-active apache2 >/dev/null; then
    echo "Apache 服務已成功重啟"
    
    # 檢查監聽狀態
    echo "檢查監聽狀態..."
    netstat -tuln | grep 80
else
    echo "錯誤：Apache 服務無法啟動，請檢查錯誤日誌"
    tail -n 20 /var/log/apache2/error.log
fi

echo "==== Apache 診斷和修復完成 ===="
echo "可以通過以下地址訪問網站："
hostname -I | awk '{print "http://"$1}'

exit 0 