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

# 檢查配置文件是否存在
if [ ! -f "$(pwd)/configs/apache/apache2.conf" ]; then
    echo "配置文件不存在，生成默認配置..."
    # 使用現有配置作為基礎
    cp /etc/apache2/apache2.conf "$(pwd)/configs/apache/apache2.conf"
    # 添加一些安全優化設置
    echo "# 安全優化設置" >> "$(pwd)/configs/apache/apache2.conf"
    echo "ServerTokens Prod" >> "$(pwd)/configs/apache/apache2.conf"
    echo "ServerSignature Off" >> "$(pwd)/configs/apache/apache2.conf"
    echo "TraceEnable Off" >> "$(pwd)/configs/apache/apache2.conf"
fi

if [ ! -f "$(pwd)/configs/apache/sites-available/000-default.conf" ]; then
    echo "站點配置文件不存在，生成默認配置..."
    # 使用現有配置作為基礎
    cp /etc/apache2/sites-available/000-default.conf "$(pwd)/configs/apache/sites-available/000-default.conf"
    # 修改站點配置
    sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html|g' "$(pwd)/configs/apache/sites-available/000-default.conf"
fi

# 複製網站文件
echo "複製網站文件..."
if [ ! -f "$(pwd)/web/index.html" ]; then
    echo "創建默認首頁..."
    cat > "$(pwd)/web/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Ubuntu Apache 自動化部署成功</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            background: #f4f4f4;
            color: #333;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: #fff;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        h1 {
            color: #4CAF50;
            text-align: center;
        }
        p {
            margin-bottom: 10px;
        }
        .success-icon {
            text-align: center;
            font-size: 72px;
            color: #4CAF50;
            margin-bottom: 20px;
        }
        .server-info {
            background: #f9f9f9;
            padding: 15px;
            border-radius: 5px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success-icon">✓</div>
        <h1>Apache 伺服器部署成功！</h1>
        <p>恭喜！您已成功配置並啟動 Apache 網頁伺服器。這個頁面確認您的服務器正在正確運行。</p>
        
        <div class="server-info">
            <h2>伺服器資訊</h2>
            <p><strong>伺服器地址：</strong> <span id="server-ip">Loading...</span></p>
            <p><strong>作業系統：</strong> Ubuntu</p>
            <p><strong>Web 伺服器：</strong> Apache</p>
            <p><strong>部署時間：</strong> <span id="deploy-time">Loading...</span></p>
        </div>
        
        <p>您可以開始將您的網站內容放在 <code>/var/www/html</code> 目錄中來替換這個頁面。</p>
    </div>

    <script>
        // 獲取當前伺服器 IP 地址
        document.getElementById('server-ip').innerText = window.location.hostname;
        
        // 設置部署時間
        document.getElementById('deploy-time').innerText = new Date().toLocaleString();
    </script>
</body>
</html>
EOF
fi

# 複製網站文件到 Apache 目錄
cp -r "$(pwd)/web/"* /var/www/html/

# 設置適當的權限
echo "設置文件權限..."
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

# 啟用必要的模組（使用 a2enmod 而不是手動加載）
echo "啟用必要的 Apache 模組..."
a2enmod rewrite
a2enmod ssl
a2enmod headers

# 應用配置文件（僅包含必要的設定）
echo "應用項目配置文件..."
# 僅修改部分安全配置，不完全覆蓋配置文件
echo "# 安全優化設置" >> /etc/apache2/apache2.conf
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf
echo "ServerSignature Off" >> /etc/apache2/apache2.conf
echo "TraceEnable Off" >> /etc/apache2/apache2.conf

# 修改默認站點配置
cp "$(pwd)/configs/apache/sites-available/000-default.conf" /etc/apache2/sites-available/000-default.conf

# 重啟 Apache 以應用配置
echo "重啟 Apache 服務以應用配置..."
systemctl restart apache2

# 檢查重啟是否成功
if ! systemctl is-active apache2 >/dev/null; then
    echo "警告：Apache 服務未正常啟動，嘗試修復..."
    # 還原配置並重啟
    if [ -f /etc/apache2/apache2.conf.backup ]; then
        cp /etc/apache2/apache2.conf.backup /etc/apache2/apache2.conf
    fi
    systemctl restart apache2
    
    if ! systemctl is-active apache2 >/dev/null; then
        echo "Apache 重啟失敗，請手動檢查配置"
        exit 1
    else
        echo "成功還原並重啟 Apache 服務"
    fi
fi

# 確保開機自動啟動
echo "設置 Apache 開機自動啟動..."
systemctl enable apache2

# 檢查自動啟動是否成功設置
if systemctl is-enabled apache2 >/dev/null; then
    echo "Apache2 已設置為開機自動啟動"
else
    echo "警告：無法通過 systemctl 設置開機自動啟動，嘗試其他方法..."
    update-rc.d apache2 defaults
fi

# 檢查配置是否正確
apache2ctl configtest

echo "==== Apache 配置完成 ===="
exit 0 