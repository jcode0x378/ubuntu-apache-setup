#!/bin/bash

# 確保腳本以 root 權限運行
if [ "$(id -u)" != "0" ]; then
   echo "此腳本需要 root 權限運行" 1>&2
   exit 1
fi

echo "開始配置防火牆規則..."

# 安裝 UFW (Uncomplicated Firewall) 如果尚未安裝
if ! command -v ufw >/dev/null 2>&1; then
    echo "安裝 UFW 防火牆..."
    apt update
    apt install -y ufw
fi

# 重置 UFW 到預設設定
echo "重置防火牆規則到預設狀態..."
ufw --force reset

# 設定預設策略
echo "設定預設策略：拒絕進入連接，允許外出連接..."
ufw default deny incoming
ufw default allow outgoing

# 允許 SSH 連接 (防止鎖定遠端連接)
echo "允許 SSH 連接 (TCP 埠 22)..."
ufw allow ssh

# 允許 HTTP 和 HTTPS 連接
echo "允許 HTTP 連接 (TCP 埠 80)..."
ufw allow http
echo "允許 HTTPS 連接 (TCP 埠 443)..."
ufw allow https

# 或者使用 'Apache Full' 設定檔 (包含 HTTP 和 HTTPS)
echo "允許 Apache 網頁伺服器連接 (HTTP 和 HTTPS)..."
ufw allow 'Apache Full'

# 允許 FTP 連接 (可選)
# echo "允許 FTP 連接 (TCP 埠 21)..."
# ufw allow ftp

# 檢查 UFW 狀態
echo "UFW 狀態："
ufw status

# 啟用 UFW
echo "啟用 UFW 防火牆..."
ufw --force enable

# 再次檢查 UFW 狀態
echo "確認 UFW 已啟用並加載正確規則："
ufw status verbose

echo "防火牆配置完成"
exit 0 