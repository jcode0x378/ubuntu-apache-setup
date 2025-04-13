#!/bin/bash
# Webmin 安裝腳本

# 顯示當前步驟
echo "==== 開始安裝 Webmin ===="

# 確保腳本以 root 權限運行
if [ "$(id -u)" != "0" ]; then
   echo "此腳本需要 root 權限運行" 1>&2
   exit 1
fi

# 更新系統套件列表
echo "更新系統套件列表..."
apt update

# 安裝必要的依賴套件
echo "安裝必要的依賴套件..."
apt install -y \
    perl \
    libnet-ssleay-perl \
    openssl \
    libauthen-pam-perl \
    libpam-runtime \
    libio-pty-perl \
    apt-show-versions \
    python3 \
    unzip \
    wget

# 添加 Webmin 倉庫
echo "添加 Webmin 倉庫..."
echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
wget -q -O- http://www.webmin.com/jcameron-key.asc | apt-key add -

# 更新套件列表
echo "更新套件列表..."
apt update

# 安裝 Webmin
echo "安裝 Webmin..."
apt install -y webmin

# 檢查安裝是否成功
if [ $? -ne 0 ]; then
    echo "Webmin 安裝失敗，嘗試手動安裝..."
    
    # 下載最新版本的 Webmin
    wget https://sourceforge.net/projects/webadmin/files/webmin/1.997/webmin_1.997_all.deb
    
    # 安裝下載的套件
    dpkg -i webmin_1.997_all.deb
    apt install -f -y
fi

# 配置 Webmin
echo "配置 Webmin..."

# 設置 Webmin 使用 SSL
sed -i 's/ssl=0/ssl=1/g' /etc/webmin/miniserv.conf

# 設置 Webmin 監聽所有介面
sed -i 's/listen=127.0.0.1/listen=0.0.0.0/g' /etc/webmin/miniserv.conf

# 設置 Webmin 端口
sed -i 's/port=10000/port=10000/g' /etc/webmin/miniserv.conf

# 設置 Webmin 登入設定
sed -i 's/loginbanner=1/loginbanner=0/g' /etc/webmin/miniserv.conf

# 重啟 Webmin 服務
echo "重啟 Webmin 服務..."
systemctl restart webmin

# 檢查服務狀態
if systemctl is-active webmin >/dev/null; then
    echo "Webmin 服務已成功啟動"
else
    echo "警告：Webmin 服務啟動失敗，嘗試修復..."
    systemctl restart webmin
    sleep 5
    
    if ! systemctl is-active webmin >/dev/null; then
        echo "Webmin 服務無法啟動，請手動檢查問題"
        exit 1
    fi
fi

# 設置開機自動啟動
echo "設置 Webmin 開機自動啟動..."
systemctl enable webmin

# 創建管理員用戶（如果不存在）
if ! grep -q "admin:" /etc/shadow; then
    echo "創建 Webmin 管理員用戶..."
    useradd -m -s /bin/bash admin
    echo "admin:admin123" | chpasswd
fi

# 添加管理員到 Webmin 用戶列表
if ! grep -q "admin:" /etc/webmin/miniserv.users; then
    echo "admin: x 0" >> /etc/webmin/miniserv.users
fi

# 設置管理員權限
if ! grep -q "admin: " /etc/webmin/webmin.acl; then
    echo "admin: " >> /etc/webmin/webmin.acl
fi

# 顯示訪問信息
echo ""
echo "============================================================"
echo "Webmin 安裝完成！"
echo "============================================================"
echo "訪問地址：https://$(hostname -I | awk '{print $1}'):10000"
echo "預設用戶名：admin"
echo "預設密碼：admin123"
echo "請在首次登入後立即修改密碼！"
echo "============================================================"

echo "==== Webmin 安裝完成 ===="
exit 0 