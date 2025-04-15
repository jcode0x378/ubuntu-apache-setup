#!/bin/bash
# Apache 配置腳本

echo "==== 開始配置 Apache 伺服器 ===="

# 備份原始配置
echo "備份原始配置文件..."
if [ -f /etc/apache2/apache2.conf ]; then
    cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.backup
fi
if [ -f /etc/apache2/sites-available/000-default.conf ]; then
    cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.backup
fi

# 確保 ports.conf 正確配置
echo "配置 Apache 監聽端口..."
cat > /etc/apache2/ports.conf << EOF
# 配置 Apache 明確監聽 IPv4 和 IPv6
Listen 0.0.0.0:80
Listen [::]:80

<IfModule ssl_module>
    Listen 0.0.0.0:443
    Listen [::]:443
</IfModule>
EOF

# 修改 Apache 主配置文件
echo "修改 Apache 主配置文件..."
cat >> /etc/apache2/apache2.conf << EOF

# 允許訪問 /home 目錄中的網站
<Directory /home/*/www>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

# 安全優化設置
ServerTokens Prod
ServerSignature Off
TraceEnable Off
EOF

# 配置默認站點
echo "配置默認站點..."
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

# 複製網站文件到 Apache 目錄
echo "複製網站文件到 Apache 目錄..."

# 創建測試頁面
echo "創建測試頁面..."
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>LAMP 自動部署成功</title>
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
    <h1>伺服器設定成功！</h1>
    <div class="success">
        <p>恭喜您！您的 LAMP (Linux, Apache, MySQL, PHP) 伺服器已成功設定。</p>
        <p>這是一個自動生成的測試頁面，表示 Apache 伺服器已正確設定並運行。</p>
        <p>伺服器時間: <?php echo date('Y-m-d H:i:s'); ?></p>
        <p>伺服器 IP: <?php echo $_SERVER['SERVER_ADDR']; ?></p>
    </div>
</body>
</html>
EOF

# 創建 phpinfo 頁面用於測試
echo "創建 PHP 資訊頁面..."
cat > /var/www/html/info.php << EOF
<?php
phpinfo();
EOF

# 確保 Apache 目錄權限正確
echo "設置目錄權限..."
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;
chown -R www-data:www-data /var/www/html

# 啟用必要的模組
echo "啟用必要的 Apache 模組..."
a2enmod rewrite
a2enmod ssl
a2enmod headers

# 重啟 Apache 以應用配置
echo "重啟 Apache 服務以應用配置..."
systemctl restart apache2

# 檢查重啟是否成功
if ! systemctl is-active apache2 >/dev/null; then
    echo "警告：Apache 服務未正常啟動，嘗試修復..."
    # 查看錯誤日誌
    tail -n 20 /var/log/apache2/error.log
    
    # 執行 Apache 配置測試
    apache2ctl -t
    
    # 嘗試再次重啟
    systemctl restart apache2
    
    if ! systemctl is-active apache2 >/dev/null; then
        echo "Apache 重啟失敗，請手動檢查配置"
        exit 1
    else
        echo "成功重啟 Apache 服務"
    fi
fi

# 確保 Apache 開機自動啟動
echo "設置 Apache 開機自動啟動..."
systemctl enable apache2

# 驗證監聽狀態
echo "驗證 Apache 監聽狀態..."
netstat -tuln | grep 80

# 輸出完成訊息
echo "==== Apache 配置完成 ===="
echo "可以通過以下地址訪問網站："
hostname -I | awk '{print "http://"$1}'

exit 0 