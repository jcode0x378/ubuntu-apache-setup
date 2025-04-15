#!/bin/bash
# 為現有用戶添加 FTP 訪問權限腳本

# 顯示當前步驟
echo "==== 開始為用戶添加 FTP 訪問權限 ===="

# 確保腳本以 root 權限運行
if [ "$(id -u)" != "0" ]; then
   echo "此腳本需要 root 權限運行" 1>&2
   exit 1
fi

# 參數設置
USERNAME="3311231016"
USER_HOME=$(eval echo ~$USERNAME)
WWW_DIR="$USER_HOME/www"
# 設定用戶密碼 - 這裡設為預設密碼，您可以根據需要修改
USER_PASSWORD="3311231016" # 預設使用學號作為密碼

# 為用戶設定密碼
echo "為用戶 $USERNAME 設定密碼..."
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "密碼已設定"

# 檢查 vsftpd 是否已安裝
if ! command -v vsftpd &> /dev/null; then
    echo "錯誤：未安裝 vsftpd。請先安裝 FTP 服務器。"
    exit 1
fi

# 確保 vsftpd.userlist 文件存在
if [ ! -f "/etc/vsftpd.userlist" ]; then
    echo "創建 FTP 用戶列表文件..."
    touch /etc/vsftpd.userlist
fi

# 將用戶添加到 FTP 允許列表
echo "添加用戶 $USERNAME 到 FTP 允許列表..."
if grep -q "$USERNAME" /etc/vsftpd.userlist; then
    echo "用戶 $USERNAME 已在 FTP 允許列表中"
else
    echo "$USERNAME" >> /etc/vsftpd.userlist
    echo "用戶 $USERNAME 已添加到 FTP 允許列表"
fi

# 確保 vsftpd 配置正確設定
echo "檢查 vsftpd 設定..."
if ! grep -q "userlist_enable=YES" /etc/vsftpd.conf; then
    echo "添加 userlist_enable 配置..."
    echo "userlist_enable=YES" >> /etc/vsftpd.conf
fi

if ! grep -q "userlist_deny=NO" /etc/vsftpd.conf; then
    echo "添加 userlist_deny 配置..."
    echo "userlist_deny=NO" >> /etc/vsftpd.conf
fi

if ! grep -q "userlist_file=/etc/vsftpd.userlist" /etc/vsftpd.conf; then
    echo "添加 userlist_file 配置..."
    echo "userlist_file=/etc/vsftpd.userlist" >> /etc/vsftpd.conf
fi

if ! grep -q "user_sub_token" /etc/vsftpd.conf; then
    echo "添加自定義用戶目錄配置..."
    echo "user_sub_token=\$USER" >> /etc/vsftpd.conf
    echo "local_root=/home/\$USER/www" >> /etc/vsftpd.conf
fi

# 確保用戶目錄存在且權限正確
echo "確保用戶目錄存在..."
mkdir -p "$WWW_DIR"

echo "設置用戶目錄權限..."
chown -R $USERNAME:$USERNAME $WWW_DIR
chmod -R 755 $WWW_DIR

# 重啟 FTP 服務
echo "重啟 FTP 服務以應用更改..."
systemctl restart vsftpd

# 檢查服務狀態
if systemctl is-active vsftpd >/dev/null; then
    echo "FTP 服務已成功重啟"
else
    echo "警告：FTP 服務重啟失敗，嘗試修復..."
    systemctl restart vsftpd
    sleep 5
    
    if ! systemctl is-active vsftpd >/dev/null; then
        echo "FTP 服務無法重啟，請手動檢查問題"
        exit 1
    fi
fi

# 顯示訪問信息
echo ""
echo "============================================================"
echo "FTP 用戶設置完成！"
echo "============================================================"
echo "FTP 伺服器地址：$(hostname -I | awk '{print $1}')"
echo "FTP 用戶名：$USERNAME"
echo "FTP 密碼：$USER_PASSWORD"
echo "FTP 目錄：$WWW_DIR"
echo "FTP 端口：21（命令端口）, 40000-50000（數據端口）"
echo "請使用支持 FTPS 的客戶端連接（如 FileZilla）"
echo "============================================================"

echo "==== 用戶 FTP 訪問權限設置完成 ===="
exit 0 