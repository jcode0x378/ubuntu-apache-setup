#!/bin/bash
# 資料庫安裝腳本

# 顯示當前步驟
echo "==== 開始安裝資料庫環境 ===="

# 設置無交互模式下的 MySQL root 密碼
MYSQL_ROOT_PASSWORD="rootpassword"
MYSQL_APP_USER="webuser"
MYSQL_APP_PASSWORD="userpassword"
MYSQL_APP_DB="webappdb"

# 更新系統套件列表
echo "更新系統套件列表..."
apt update

# 安裝必要的工具
echo "安裝基本工具..."
apt install -y curl wget nano

# 安裝 PHP 和相關模組
echo "安裝 PHP 和相關模組..."
apt install -y php php-mysql php-cli php-common php-mbstring php-zip php-gd php-xml php-curl

# 安裝 MySQL/MariaDB
echo "安裝 MariaDB 資料庫服務器..."
# 預先設置 mariadb-server 的安裝選項，避免交互式提示
export DEBIAN_FRONTEND="noninteractive"
debconf-set-selections <<< "mariadb-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"

# 安裝 MariaDB
apt install -y mariadb-server mariadb-client

# 檢查安裝是否成功
if [ $? -ne 0 ]; then
    echo "MariaDB 安裝失敗"
    exit 1
fi

# 啟動 MariaDB 服務
echo "啟動 MariaDB 服務..."
systemctl start mariadb
systemctl enable mariadb

# 檢查服務是否正在運行
if ! systemctl is-active mariadb >/dev/null; then
    echo "MariaDB 服務啟動失敗，嘗試再次啟動..."
    systemctl restart mariadb
    sleep 5
    
    if ! systemctl is-active mariadb >/dev/null; then
        echo "MariaDB 服務無法啟動，請手動檢查問題"
        exit 1
    fi
fi

# 安全配置 MariaDB
echo "設定 MariaDB 安全配置..."
# 使用預設值進行安全配置 (模擬 mysql_secure_installation)
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
-- 刪除匿名用戶
DELETE FROM mysql.user WHERE User='';
-- 禁止 root 遠端登入
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- 刪除測試資料庫和訪問權限
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- 重新載入權限表
FLUSH PRIVILEGES;
EOF

# 創建應用程序使用的資料庫和用戶
echo "創建應用程序資料庫和用戶..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
-- 創建資料庫
CREATE DATABASE IF NOT EXISTS $MYSQL_APP_DB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- 創建用戶
CREATE USER IF NOT EXISTS '$MYSQL_APP_USER'@'localhost' IDENTIFIED BY '$MYSQL_APP_PASSWORD';
-- 授予權限
GRANT ALL PRIVILEGES ON $MYSQL_APP_DB.* TO '$MYSQL_APP_USER'@'localhost';
-- 重新載入權限表
FLUSH PRIVILEGES;
EOF

# 安裝 phpMyAdmin (使用非交互方式)
echo "安裝 phpMyAdmin..."
# 預設 phpMyAdmin 配置
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"

# 安裝 phpMyAdmin
apt install -y phpmyadmin

# 確保 phpMyAdmin 配置正確
echo "確保 phpMyAdmin 配置正確..."
if [ ! -f /etc/apache2/conf-enabled/phpmyadmin.conf ]; then
    echo "創建 phpMyAdmin Apache 配置連結..."
    ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-enabled/phpmyadmin.conf
fi

# 檢查 phpMyAdmin 安裝是否成功
if [ -d /usr/share/phpmyadmin ]; then
    echo "phpMyAdmin 安裝成功"
else
    echo "phpMyAdmin 安裝失敗，嘗試手動安裝..."
    
    # 嘗試手動安裝 phpMyAdmin
    PHPMYADMIN_VERSION="5.2.1"
    PHPMYADMIN_DIR="/usr/share/phpmyadmin"
    
    # 下載 phpMyAdmin
    wget -O /tmp/phpmyadmin.tar.gz https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz
    
    # 解壓到目標目錄
    mkdir -p $PHPMYADMIN_DIR
    tar xzf /tmp/phpmyadmin.tar.gz -C /tmp
    cp -r /tmp/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages/* $PHPMYADMIN_DIR/
    
    # 創建配置檔
    cp $PHPMYADMIN_DIR/config.sample.inc.php $PHPMYADMIN_DIR/config.inc.php
    
    # 生成隨機密鑰
    BLOWFISH_SECRET=$(tr -dc 'a-zA-Z0-9~!@#$%^&*_()+}{?></";.,[]=-' < /dev/urandom | fold -w 32 | head -n 1)
    sed -i "s/\$cfg\['blowfish_secret'\] = ''/\$cfg\['blowfish_secret'\] = '$BLOWFISH_SECRET'/g" $PHPMYADMIN_DIR/config.inc.php
    
    # 設置正確的權限
    chown -R www-data:www-data $PHPMYADMIN_DIR
    
    # 創建 Apache 配置
    echo "Alias /phpmyadmin $PHPMYADMIN_DIR" > /etc/apache2/conf-available/phpmyadmin.conf
    echo "<Directory $PHPMYADMIN_DIR>" >> /etc/apache2/conf-available/phpmyadmin.conf
    echo "    Options FollowSymLinks" >> /etc/apache2/conf-available/phpmyadmin.conf
    echo "    DirectoryIndex index.php" >> /etc/apache2/conf-available/phpmyadmin.conf
    echo "    AllowOverride All" >> /etc/apache2/conf-available/phpmyadmin.conf
    echo "    Require all granted" >> /etc/apache2/conf-available/phpmyadmin.conf
    echo "</Directory>" >> /etc/apache2/conf-available/phpmyadmin.conf
    
    # 啟用配置
    a2enconf phpmyadmin
fi

# 優化 PHP 配置
echo "優化 PHP 配置..."
for phpver in /etc/php/*/apache2/php.ini; do
    echo "更新 PHP 配置檔: $phpver"
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = 20M/' $phpver
    sed -i 's/^post_max_size.*/post_max_size = 21M/' $phpver
    sed -i 's/^memory_limit.*/memory_limit = 256M/' $phpver
    sed -i 's/^max_execution_time.*/max_execution_time = 300/' $phpver
done

# 重啟 Apache 以套用 PHP 設定
echo "重啟 Apache 以套用 PHP 設定..."
systemctl restart apache2

# 建立資料庫設定檔，方便 web 應用程式使用
echo "建立資料庫設定檔..."
cat > /var/www/html/db-config.php << EOF
<?php
/**
 * 資料庫連接設定
 */

// 資料庫主機
define('DB_HOST', 'localhost');

// 資料庫用戶名
define('DB_USER', '$MYSQL_APP_USER');

// 資料庫密碼
define('DB_PASSWORD', '$MYSQL_APP_PASSWORD');

// 資料庫名稱
define('DB_NAME', '$MYSQL_APP_DB');

// 建立連接
\$conn = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);

// 檢查連接
if (\$conn->connect_error) {
    die("連接失敗: " . \$conn->connect_error);
}

// 設置字符編碼
\$conn->set_charset("utf8mb4");
?>
EOF

# 設定適當的檔案權限
chown www-data:www-data /var/www/html/db-config.php
chmod 640 /var/www/html/db-config.php

# 創建一個簡單的 PHP 測試頁面
echo "創建 PHP 資訊頁面..."
cat > /var/www/html/phpinfo.php << 'EOF'
<?php
phpinfo();
?>
EOF
chown www-data:www-data /var/www/html/phpinfo.php
chmod 644 /var/www/html/phpinfo.php

# 創建一個簡單的測試頁面
echo "創建資料庫測試頁面..."
cat > /var/www/html/db-test.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>資料庫連接測試</title>
    <meta charset="utf-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background: #f4f4f4;
            color: #333;
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
        .result {
            padding: 15px;
            margin: 10px 0;
            border-radius: 4px;
        }
        .success {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .error {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .info {
            background-color: #e1f5fe;
            color: #0c5460;
            border: 1px solid #bee5eb;
        }
        .code {
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 4px;
            font-family: monospace;
            overflow-x: auto;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>資料庫連接測試</h1>
        
        <?php
        require_once 'db-config.php';
        
        echo '<div class="result success">';
        echo '<strong>連接成功！</strong> 成功連接到資料庫 ' . DB_NAME;
        echo '</div>';
        
        // 顯示 MySQL/MariaDB 版本
        $version_result = $conn->query("SELECT VERSION() as version");
        if ($version_result) {
            $version_row = $version_result->fetch_assoc();
            echo '<div class="result info">';
            echo '<strong>資料庫版本：</strong> ' . $version_row['version'];
            echo '</div>';
        }
        
        // 顯示資料庫表清單
        $tables_result = $conn->query("SHOW TABLES");
        echo '<div class="result info">';
        echo '<strong>資料庫表：</strong><br>';
        if ($tables_result->num_rows > 0) {
            echo '<ul>';
            while ($table = $tables_result->fetch_array()) {
                echo '<li>' . $table[0] . '</li>';
            }
            echo '</ul>';
        } else {
            echo '目前沒有資料表，資料庫是空的。';
        }
        echo '</div>';
        
        // 顯示 phpMyAdmin 連結
        echo '<div class="result info">';
        echo '<strong>資料庫管理：</strong><br>';
        echo '您可以使用 <a href="/phpmyadmin/" target="_blank">phpMyAdmin</a> 來管理您的資料庫。';
        echo '<br>用戶名: root';
        echo '<br>密碼: ' . htmlspecialchars('rootpassword');
        echo '</div>';
        
        // 關閉連接
        $conn->close();
        ?>
        
        <h2>如何使用此資料庫連接</h2>
        <div class="code">
        // 包含資料庫配置文件<br>
        require_once 'db-config.php';<br><br>
        
        // 現在你可以使用 \$conn 變數執行查詢<br>
        \$sql = "SELECT * FROM your_table";<br>
        \$result = \$conn->query(\$sql);<br><br>
        
        // 處理查詢結果<br>
        if (\$result->num_rows > 0) {<br>
        &nbsp;&nbsp;while(\$row = \$result->fetch_assoc()) {<br>
        &nbsp;&nbsp;&nbsp;&nbsp;echo "id: " . \$row["id"]. " - Name: " . \$row["name"]. "<br>";<br>
        &nbsp;&nbsp;}<br>
        } else {<br>
        &nbsp;&nbsp;echo "0 結果";<br>
        }<br><br>
        
        // 關閉連接<br>
        \$conn->close();
        </div>
    </div>
</body>
</html>
EOF

# 設定適當的檔案權限
chown www-data:www-data /var/www/html/db-test.php
chmod 644 /var/www/html/db-test.php

# 建立一個簡單的 SQL 示例資料表
echo "建立範例資料表..."

mysql -u root -p"$MYSQL_ROOT_PASSWORD" $MYSQL_APP_DB <<EOF
-- 建立用戶資料表
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 建立文章資料表
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 建立評論資料表
CREATE TABLE IF NOT EXISTS comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    comment TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 插入示範資料
INSERT INTO users (username, password, email) VALUES
('admin', 'demo', 'admin@example.com'),
('user1', 'demo', 'user1@example.com');

INSERT INTO posts (user_id, title, content) VALUES
(1, '歡迎使用我們的網站', '這是第一篇文章，歡迎大家來到我們的網站！'),
(2, '資料庫測試文章', '這是一篇用於測試資料庫功能的文章。');

INSERT INTO comments (post_id, user_id, comment) VALUES
(1, 2, '感謝分享！'),
(2, 1, '這篇文章很有用！');
EOF

# 最後的一些檢查
echo "執行最終檢查..."

# 確保 PHP 模組都啟用
a2enmod php

# 確保 Apache 已啟用 PHP
php_handlers=$(grep -r "php" /etc/apache2/mods-enabled/)
if [ -z "$php_handlers" ]; then
    echo "PHP 模組似乎未啟用，嘗試修復..."
    for phpver in /etc/php/*/apache2/php.ini; do
        phpversion=$(echo $phpver | grep -oP '(?<=/etc/php/)[0-9]+\.[0-9]+(?=/apache2)')
        if [ ! -z "$phpversion" ]; then
            echo "啟用 PHP $phpversion 模組..."
            a2enmod php$phpversion
        fi
    done
fi

# 最後一步：重啟 Apache，確保所有設置都生效
systemctl restart apache2
sleep 3

# 檢查 Apache 是否成功啟動
if systemctl is-active apache2 > /dev/null; then
    echo "Apache 伺服器已成功重啟"
else
    echo "警告：Apache 伺服器未成功啟動，請檢查配置"
    systemctl status apache2
fi

echo "==== 資料庫環境安裝完成 ===="
echo "您可以通過以下網址訪問 phpMyAdmin：http://YOUR_SERVER_IP/phpmyadmin/"
echo "資料庫連接測試頁面：http://YOUR_SERVER_IP/db-test.php"
echo "PHP 資訊頁面：http://YOUR_SERVER_IP/phpinfo.php"
echo "資料庫配置信息："
echo "數據庫名稱：$MYSQL_APP_DB"
echo "應用程序用戶：$MYSQL_APP_USER"
echo "應用程序密碼：$MYSQL_APP_PASSWORD"
echo "root 密碼：$MYSQL_ROOT_PASSWORD"
echo ""
echo "⚠️ 請記下此資訊，並在生產環境中更改這些預設密碼 ⚠️"
exit 0 