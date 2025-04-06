#!/bin/bash
# Apache 安裝腳本

# 顯示當前步驟
echo "==== 開始 Apache 安裝 ===="

# 更新系統套件列表
echo "更新系統套件列表..."
apt update

# 安裝 Apache2
echo "安裝 Apache2..."
apt install apache2 -y

# 檢查安裝是否成功
if [ $? -ne 0 ]; then
    echo "Apache2 安裝失敗"
    exit 1
fi

# 啟動 Apache 服務
echo "啟動 Apache 服務..."
systemctl start apache2
systemctl enable apache2

# 檢查服務是否正在運行
if ! systemctl is-active apache2 >/dev/null; then
    echo "Apache2 服務啟動失敗"
    exit 1
fi

# 確保開機自動啟動
echo "設置 Apache 開機自動啟動..."
systemctl enable apache2

# 檢查自動啟動是否成功設置
if systemctl is-enabled apache2 >/dev/null; then
    echo "Apache2 已設置為開機自動啟動"
else
    echo "警告：無法設置 Apache2 開機自動啟動，嘗試其他方法..."
    # 額外的確保方法
    update-rc.d apache2 defaults
fi

# 創建一個系統啟動服務檢查腳本
echo "創建系統啟動服務檢查腳本..."
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

# 安裝額外的軟體套件
echo "安裝 Apache 相關套件..."
apt install -y apache2-utils ssl-cert

echo "==== Apache 安裝完成並設置為開機自動啟動 ===="
exit 0 