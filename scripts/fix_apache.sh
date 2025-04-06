#!/bin/bash
# Apache 修復腳本

echo "==== 開始修復 Apache 服務 ===="

# 檢查是否以 root 權限運行
if [ "$(id -u)" -ne 0 ]; then
    echo "請以 sudo 或 root 權限運行此腳本"
    exit 1
fi

# 檢查 Apache 安裝
echo "檢查 Apache 安裝狀態..."
if ! dpkg -l | grep -q apache2; then
    echo "Apache 未安裝，正在安裝..."
    apt update && apt install -y apache2
else
    echo "Apache 已安裝"
fi

# 備份配置文件
echo "備份當前配置文件..."
timestamp=$(date +%Y%m%d_%H%M%S)
if [ -f /etc/apache2/apache2.conf ]; then
    cp /etc/apache2/apache2.conf "/etc/apache2/apache2.conf.backup_$timestamp"
fi

# 重置 Apache 配置
echo "重置 Apache 配置..."
apt-get --purge --reinstall install apache2-data -y

# 檢查模組
echo "檢查並修復 Apache 模組..."
echo "啟用基本模組..."
a2enmod rewrite
a2enmod ssl
a2enmod headers

# 創建基本的 HTML 頁面
echo "創建測試頁面..."
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Apache 修復成功</title>
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
            text-align: center;
        }
        h1 {
            color: #4CAF50;
        }
        .success-icon {
            font-size: 72px;
            color: #4CAF50;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success-icon">✓</div>
        <h1>Apache 修復成功！</h1>
        <p>Apache 伺服器已成功修復並重新啟動</p>
        <p>IP 地址: <span id="server-ip">Loading...</span></p>
        <p>時間: <span id="current-time">Loading...</span></p>
    </div>
    <script>
        // 獲取當前伺服器 IP 地址
        document.getElementById('server-ip').innerText = window.location.hostname;
        
        // 設置當前時間
        document.getElementById('current-time').innerText = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

# 設置權限
echo "設置文件權限..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# 檢查端口
echo "檢查 80 端口狀態..."
if netstat -tulpn | grep -q ":80 "; then
    echo "警告: 80 端口已被占用，請確認占用進程..."
    netstat -tulpn | grep ":80 "
    echo "嘗試停止占用端口的程序..."
    fuser -k 80/tcp
    sleep 2
fi

# 重啟 Apache 服務
echo "重啟 Apache 服務..."
systemctl stop apache2
sleep 2
systemctl start apache2
sleep 2

# 檢查 Apache 狀態
echo "檢查 Apache 服務狀態..."
if systemctl is-active apache2 > /dev/null; then
    echo "✓ Apache 服務已成功啟動!"
else
    echo "⚠️ Apache 服務啟動失敗，顯示錯誤日誌:"
    systemctl status apache2
    echo ""
    echo "查看更詳細的錯誤日誌:"
    tail -n 20 /var/log/apache2/error.log
fi

# 確保開機自動啟動
echo "確保 Apache 開機自動啟動..."
systemctl enable apache2

# 檢查自動啟動是否成功設置
if systemctl is-enabled apache2 >/dev/null; then
    echo "Apache2 已設置為開機自動啟動"
else
    echo "警告：無法通過 systemctl 設置開機自動啟動，嘗試其他方法..."
    update-rc.d apache2 defaults
fi

# 創建系統啟動服務檢查腳本
echo "創建/更新系統啟動服務檢查腳本..."
cat > /etc/init.d/check-apache << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          check-apache
# Required-Start:    $remote_fs $syslog $network
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: 確保 Apache 服務運行
# Description:       在系統啟動時檢查 Apache 服務並確保其運行
### END INIT INFO

case "$1" in
  start)
    echo "檢查 Apache 服務..."
    if ! systemctl is-active apache2 > /dev/null; then
      echo "啟動 Apache 服務..."
      systemctl start apache2
    fi
    ;;
  stop)
    echo "check-apache 服務不需要停止"
    ;;
  restart)
    echo "重新啟動 Apache 服務..."
    systemctl restart apache2
    ;;
  status)
    systemctl status apache2
    ;;
  *)
    echo "用法: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac

exit 0
EOF

# 設置執行權限
chmod +x /etc/init.d/check-apache

# 將腳本添加到啟動序列
update-rc.d check-apache defaults

# 創建系統級別的自啟動服務 (使用 systemd)
echo "創建 systemd 服務以確保 Apache 自動啟動..."
cat > /etc/systemd/system/apache-autostart.service << 'EOF'
[Unit]
Description=確保 Apache 在系統啟動時運行
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'if ! systemctl is-active apache2 > /dev/null; then systemctl start apache2; fi'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 重新加載 systemd 配置
systemctl daemon-reload

# 啟用服務
systemctl enable apache-autostart.service

# 設置開機啟動的另一個方法 (使用 crontab)
echo "設置 crontab 開機啟動項..."
(crontab -l 2>/dev/null; echo "@reboot systemctl start apache2") | sort | uniq | crontab -

# 檢查防火牆
echo "檢查防火牆設置..."
if command -v ufw > /dev/null; then
    if ufw status | grep -q "active"; then
        echo "防火牆已啟用，確保允許 HTTP 和 HTTPS 連接..."
        ufw allow 80/tcp
        ufw allow 443/tcp
        echo "防火牆規則已更新"
    else
        echo "防火牆未啟用"
    fi
fi

# 測試 Apache 訪問
echo "測試 Apache 本地訪問..."
if curl -s --head http://localhost | grep -q "200 OK"; then
    echo "✓ 本地測試成功！Apache 運行正常"
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo "您現在可以通過瀏覽器訪問: http://$IP_ADDRESS"
else
    echo "⚠️ 本地測試失敗，Apache 可能仍有問題"
    echo "請檢查配置文件是否有語法錯誤："
    apache2ctl configtest
fi

echo "==== Apache 修復完成 ===="
echo "如果仍然無法訪問 Apache，請考慮以下步驟："
echo "1. 檢查虛擬機網絡設置（應為橋接模式）"
echo "2. 檢查實體機防火牆設置"
echo "3. 重啟虛擬機並再次嘗試"
echo "4. 如果以上步驟都不奏效，請重新安裝 Apache："
echo "   sudo apt-get remove --purge apache2"
echo "   sudo apt-get install apache2"
echo "5. 檢查 $IP_ADDRESS 是否與區域網內其他設備 IP 衝突"
exit 0 