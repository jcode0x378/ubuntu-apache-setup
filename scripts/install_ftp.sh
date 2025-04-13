#!/bin/bash
# FTP 伺服器安裝腳本

# 顯示當前步驟
echo "==== 開始安裝 FTP 伺服器 ===="

# 確保腳本以 root 權限運行
if [ "$(id -u)" != "0" ]; then
   echo "此腳本需要 root 權限運行" 1>&2
   exit 1
fi

# 更新系統套件列表
echo "更新系統套件列表..."
apt update

# 安裝 vsftpd
echo "安裝 vsftpd FTP 伺服器..."
apt install -y vsftpd

# 備份原始配置文件
echo "備份原始配置文件..."
cp /etc/vsftpd.conf /etc/vsftpd.conf.backup

# 配置 vsftpd
echo "配置 vsftpd..."
cat > /etc/vsftpd.conf << EOF
# 基本設置
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
force_local_logins_ssl=YES
force_local_data_ssl=YES
rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem

# 被動模式設置
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

# 日誌設置
xferlog_file=/var/log/vsftpd.log
xferlog_std_format=YES

# 目錄設置
local_root=/var/www/html
user_sub_token=\$USER
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
EOF

# 創建 SSL 證書
echo "生成 SSL 證書..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/vsftpd.pem \
    -out /etc/ssl/private/vsftpd.pem \
    -subj "/C=TW/ST=Taiwan/L=Taipei/O=Development/CN=localhost"

# 創建 FTP 用戶
echo "創建 FTP 用戶..."
FTP_USER="ftpuser"
FTP_PASS="ftppassword"

# 檢查用戶是否已存在
if ! id "$FTP_USER" &>/dev/null; then
    useradd -m -s /bin/bash $FTP_USER
    echo "$FTP_USER:$FTP_PASS" | chpasswd
fi

# 添加用戶到允許列表
echo "$FTP_USER" > /etc/vsftpd.userlist

# 設置目錄權限
echo "設置目錄權限..."
chown -R $FTP_USER:$FTP_USER /var/www/html
chmod -R 755 /var/www/html

# 創建必要的目錄
mkdir -p /var/run/vsftpd/empty
chmod 755 /var/run/vsftpd/empty

# 重啟 FTP 服務
echo "重啟 FTP 服務..."
systemctl restart vsftpd
systemctl enable vsftpd

# 檢查服務狀態
if systemctl is-active vsftpd >/dev/null; then
    echo "FTP 服務已成功啟動"
else
    echo "警告：FTP 服務啟動失敗，嘗試修復..."
    systemctl restart vsftpd
    sleep 5
    
    if ! systemctl is-active vsftpd >/dev/null; then
        echo "FTP 服務無法啟動，請手動檢查問題"
        exit 1
    fi
fi

# 顯示訪問信息
echo ""
echo "============================================================"
echo "FTP 伺服器安裝完成！"
echo "============================================================"
echo "FTP 伺服器地址：$(hostname -I | awk '{print $1}')"
echo "FTP 用戶名：$FTP_USER"
echo "FTP 密碼：$FTP_PASS"
echo "FTP 端口：21（命令端口）, 40000-50000（數據端口）"
echo "請使用支持 FTPS 的客戶端連接（如 FileZilla）"
echo "============================================================"

echo "==== FTP 伺服器安裝完成 ===="
exit 0 