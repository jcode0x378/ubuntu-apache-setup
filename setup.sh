#!/bin/bash

# 確保腳本以 root 權限運行
if [ "$(id -u)" != "0" ]; then
   echo "此腳本需要 root 權限運行" 1>&2
   echo "請使用 sudo ./setup.sh 運行" 1>&2
   exit 1
fi

# 設置顏色變量
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 無顏色

echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Ubuntu LAMP 環境自動部署腳本${NC}"
echo -e "${BLUE}================================${NC}"

# 檢查系統是否為 Ubuntu
if [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    if [ "$DISTRIB_ID" != "Ubuntu" ]; then
        echo -e "${RED}此腳本只支持 Ubuntu 系統${NC}" 1>&2
        exit 1
    fi
else
    echo -e "${RED}無法確認系統為 Ubuntu${NC}" 1>&2
    exit 1
fi

echo -e "${YELLOW}開始安裝程序...${NC}"

# 確保腳本目錄存在
SCRIPTS_DIR="./scripts"
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo -e "${RED}腳本目錄不存在，請確認您在正確的目錄中運行此腳本${NC}" 1>&2
    exit 1
fi

# 確保所有腳本有執行權限
echo -e "${YELLOW}設置腳本執行權限...${NC}"
chmod +x "$SCRIPTS_DIR/"*.sh

# 更新系統
echo -e "\n${YELLOW}正在更新系統...${NC}"
bash "$SCRIPTS_DIR/update_system.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}系統更新失敗${NC}" 1>&2
    exit 1
fi
echo -e "${GREEN}系統更新完成${NC}"

# 安裝 Apache 伺服器
echo -e "\n${YELLOW}正在安裝 Apache 伺服器...${NC}"
bash "$SCRIPTS_DIR/install_apache.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Apache 安裝失敗${NC}" 1>&2
    exit 1
fi
echo -e "${GREEN}Apache 安裝完成${NC}"

# 安裝和配置資料庫
echo -e "\n${YELLOW}正在安裝和配置 MariaDB 資料庫...${NC}"
bash "$SCRIPTS_DIR/install_database.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}資料庫安裝失敗${NC}" 1>&2
    exit 1
fi
echo -e "${GREEN}資料庫安裝完成${NC}"

# 配置 Apache
echo -e "\n${YELLOW}正在配置 Apache...${NC}"
bash "$SCRIPTS_DIR/configure_apache.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Apache 配置失敗${NC}" 1>&2
    exit 1
fi
echo -e "${GREEN}Apache 配置完成${NC}"

# 配置防火牆
echo -e "\n${YELLOW}正在配置防火牆...${NC}"
bash "$SCRIPTS_DIR/configure_firewall.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}防火牆配置失敗${NC}" 1>&2
    exit 1
fi
echo -e "${GREEN}防火牆配置完成${NC}"

# 安裝 FTP 伺服器
echo -e "\n${YELLOW}正在安裝 FTP 伺服器...${NC}"
bash "$SCRIPTS_DIR/install_ftp.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}FTP 伺服器安裝失敗${NC}" 1>&2
    exit 1
fi
echo -e "${GREEN}FTP 伺服器安裝完成${NC}"

# 直接創建3311231016用戶
echo -e "\n${YELLOW}正在創建3311231016用戶...${NC}"
USERNAME="3311231016"

# 檢查用戶是否已存在
if id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}用戶 $USERNAME 已存在，跳過創建用戶步驟${NC}"
else
    # 創建用戶
    useradd -m -s /bin/bash "$USERNAME"
    
    # 將用戶添加到必要的組
    usermod -aG sudo "$USERNAME"
    echo -e "${GREEN}用戶 $USERNAME 創建成功${NC}"
fi

# 創建www目錄
echo -e "${YELLOW}正在為用戶 $USERNAME 創建 Web 目錄...${NC}"
USER_HOME=$(eval echo ~$USERNAME)
WWW_DIR="$USER_HOME/www"

mkdir -p "$WWW_DIR"
chown -R "$USERNAME":"$USERNAME" "$WWW_DIR"
chmod -R 755 "$WWW_DIR"

# 創建Apache虛擬主機配置
echo -e "${YELLOW}正在配置 Apache 虛擬主機...${NC}"
VHOST_CONF="/etc/apache2/sites-available/$USERNAME.conf"

# 獲取服務器IP
SERVER_IP=$(hostname -I | awk '{print $1}')

cat > "$VHOST_CONF" << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $WWW_DIR
    ServerName $SERVER_IP
    ServerAlias www.$USERNAME.local
    
    <Directory $WWW_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/$USERNAME-error.log
    CustomLog \${APACHE_LOG_DIR}/$USERNAME-access.log combined
</VirtualHost>
EOF

# 啟用站點
a2ensite "$USERNAME.conf"

# 重啟 Apache
systemctl restart apache2

# 獲取伺服器 IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "\n${BLUE}================================${NC}"
echo -e "${GREEN}Ubuntu LAMP 環境部署完成!${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "
${YELLOW}您可以通過以下方式訪問網站:${NC}
- 網站主頁: http://$SERVER_IP/
- 用戶網站: http://$SERVER_IP/
- phpMyAdmin: http://$SERVER_IP/phpmyadmin

${YELLOW}數據庫信息:${NC}
- 數據庫名稱: webapp_db
- 用戶名: webapp_user
- 密碼: webapp_pass

${YELLOW}FTP 連線資訊:${NC}
- FTP 伺服器: $SERVER_IP
- 使用者名稱: ftpuser
- 密碼: ftppassword
- 端口: 21（命令）, 40000-50000（被動模式數據）
- 請使用支援 FTPS 的客戶端（如 FileZilla）連線

${YELLOW}用戶資訊:${NC}
- 用戶名: $USERNAME
- 網站目錄: $WWW_DIR

${RED}⚠️ 重要安全提示:${NC}
  請記得在生產環境中更改所有默認密碼和配置!
"

echo -e "${GREEN}感謝使用本自動化部署腳本!${NC}" 