# 版本: V1.1

# Ubuntu Apache 自動化部署項目 (LAMP 環境)

這個項目提供了在 Ubuntu 虛擬機中自動部署 LAMP (Linux, Apache, MySQL/MariaDB, PHP) 環境的完整解決方案，確保伺服器配置正確並可從宿主機訪問。

## 項目概述

本項目旨在通過自動化腳本在新建的 Ubuntu 虛擬機內部署並配置 LAMP 環境，實現以下目標：

- 基礎 Apache 伺服器的安裝與配置
- MariaDB 資料庫系統的安裝和設置
- PHP 環境配置與整合
- phpMyAdmin 資料庫管理界面
- 安全設置與優化
- 網絡配置，確保從實體機可訪問虛擬機中的網頁
- 完整的自動化部署流程，最小化人工干預
- 實現虛擬機與宿主機之間的複製貼上功能
- **確保 Apache 服務在虛擬機重啟後自動運行**

## 項目結構

```
├── README.md                 # 項目說明文檔
├── setup.sh                  # 主設置腳本
├── scripts/                  # 輔助腳本目錄
│   ├── install_apache.sh     # Apache 安裝腳本
│   ├── configure_apache.sh   # Apache 配置腳本
│   ├── setup_firewall.sh     # 防火牆設置腳本
│   ├── network_config.sh     # 網絡配置腳本
│   ├── install_database.sh   # 資料庫安裝腳本
│   └── fix_apache.sh         # Apache 修復腳本
├── configs/                  # 配置文件目錄
│   ├── apache/               # Apache 配置文件
│   │   ├── apache2.conf      # Apache 主配置文件
│   │   └── sites-available/  # 站點配置目錄
│   │       └── 000-default.conf  # 默認站點配置
└── web/                      # 網站文件目錄（示例）
    └── index.html            # 示例首頁
```

## 使用方法

### 前提條件

- 已安裝 Ubuntu 虛擬機（推薦 20.04 LTS 或更高版本）
- 虛擬機可接入網路
- 具有 sudo 權限的用戶帳號

### 在新 Ubuntu 虛擬機中部署

1. 首先更新系統並安裝 git：

```bash
sudo apt update
sudo apt install git -y
```

2. 克隆此倉庫：

```bash
git clone https://github.com/你的用戶名/ubuntu-apache-setup.git
```

3. 進入項目目錄並設置執行權限：

```bash
cd ubuntu-apache-setup
# 設置所有腳本的執行權限
chmod +x setup.sh
chmod +x scripts/*.sh
```

4. 啟動安裝腳本：

```bash
sudo ./setup.sh
```

5. 按照腳本提示完成配置：
   - 選擇是否安裝 MariaDB 資料庫和 phpMyAdmin
   - 選擇是否安裝 VirtualBox Guest Additions 以啟用複製貼上功能

### 驗證部署

安裝完成後，可通過以下方式驗證部署是否成功：

1. 在虛擬機內部檢查 Apache 狀態：

```bash
sudo systemctl status apache2
```

2. 檢查資料庫狀態（如果已安裝）：

```bash
sudo systemctl status mariadb
```

3. 在實體機上通過瀏覽器訪問：

```
# 訪問 Apache 網站
http://[虛擬機IP地址]

# 訪問資料庫測試頁面
http://[虛擬機IP地址]/db-test.php

# 訪問 phpMyAdmin
http://[虛擬機IP地址]/phpmyadmin
```

## 資料庫功能

本項目提供完整的資料庫環境，包括：

### 已安裝組件

- MariaDB 資料庫伺服器
- PHP 和必要的 PHP 模組
- phpMyAdmin 資料庫管理界面
- 範例資料庫和示範資料表

### 預設帳號

- **資料庫名稱**：webappdb
- **應用程式用戶**：webuser
- **應用程式密碼**：userpassword
- **root 用戶密碼**：rootpassword

> ⚠️ 請注意：在生產環境中，請務必更改這些預設密碼！

### 使用資料庫

已經設置好的資料庫連接檔案位於 `/var/www/html/db-config.php`，您可以在任何 PHP 檔案中引入它來使用資料庫連接：

```php
// 引入資料庫連接檔案
require_once 'db-config.php';

// 使用 $conn 進行查詢
$sql = "SELECT * FROM users";
$result = $conn->query($sql);

// 處理查詢結果
if ($result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        echo "User: " . $row["username"] . "<br>";
    }
}

// 關閉連接
$conn->close();
```

### 資料庫測試頁面

安裝完成後，可通過以下 URL 訪問資料庫測試頁面：

```
http://[虛擬機IP地址]/db-test.php
```

該頁面提供以下功能：
- 確認資料庫連接是否正常
- 顯示資料庫版本信息
- 顯示現有資料表列表
- 提供 phpMyAdmin 連結
- 提供基本的資料庫使用示例代碼

## 持久化運行 Apache 服務

本專案特別設置了多重機制確保 Apache 服務在虛擬機重啟後自動運行：

1. 使用 `systemctl enable` 命令啟用 Apache 服務的自動啟動
2. 創建自定義啟動腳本 `/etc/init.d/check-apache`，確保在系統啟動時檢查並啟動 Apache
3. 設置 systemd 服務 `apache-autostart.service`，在系統啟動後監控 Apache 服務
4. 使用 crontab 設置系統啟動項，添加額外保障

這些多重機制確保了 Apache 服務在任何情況下都會在系統啟動時自動運行，不需要手動干預。

### 如果 Apache 未自動啟動

如果出現罕見情況 Apache 未自動啟動，可以執行修復腳本：

```bash
sudo ./scripts/fix_apache.sh
```

這將重新設置所有自動啟動機制並啟動 Apache 服務。

## 啟用複製貼上功能

本專案支援在虛擬機和宿主機之間啟用複製貼上功能，有兩種方式：

### 方式一：使用腳本安裝 Guest Additions

在運行 `setup.sh` 時，會詢問是否安裝 VirtualBox Guest Additions 以啟用複製貼上功能。選擇 'y' 將自動進行安裝。

### 方式二：手動設置

1. 在 VirtualBox 菜單中選擇：「設備」>「共用剪貼簿」>「雙向」
2. 在 VirtualBox 菜單中選擇：「設備」>「拖放」>「雙向」
3. 安裝 Guest Additions：
   ```bash
   sudo apt update
   sudo apt install -y build-essential dkms linux-headers-$(uname -r)
   # 插入 Guest Additions CD
   sudo mount /dev/cdrom /mnt
   sudo sh /mnt/VBoxLinuxAdditions.run
   sudo reboot
   ```

## 網絡連接問題解決

如果無法從宿主機連接到虛擬機的 Apache 服務器，請嘗試以下步驟：

### 1. 確認 VirtualBox 網絡設定

將虛擬機網絡模式設置為「橋接網卡」：
- 關閉虛擬機
- 在 VirtualBox 主界面：選擇虛擬機 > 設定 > 網絡
- 將「連接方式」設置為「橋接網卡」
- 選擇正確的實體網卡（通常是連接到網路的那個）
- 重新啟動虛擬機

### 2. 運行修復腳本

如果 Apache 服務存在問題，可以運行修復腳本：

```bash
sudo ./scripts/fix_apache.sh
```

### 3. 檢查防火牆設置

確保防火牆允許 HTTP 和 HTTPS 通信：

```bash
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 4. 檢查實體機防火牆

請確保宿主機的防火牆未阻止來自虛擬機 IP 的連接。

## 常見問題解答

### Q: 無法從宿主機訪問虛擬機網頁？
A: 確保虛擬機使用橋接網卡模式，並且 Apache 服務正常運行。可以運行 `./scripts/fix_apache.sh` 來修復 Apache 服務。

### Q: 虛擬機中無法使用複製貼上功能？
A: 安裝 VirtualBox Guest Additions 並在 VirtualBox 設置中開啟「共用剪貼簿」選項設為「雙向」。

### Q: Apache 服務啟動失敗？
A: 檢查配置文件是否有錯誤，運行 `sudo apache2ctl configtest` 查看具體錯誤信息，或使用修復腳本 `sudo ./scripts/fix_apache.sh`。

### Q: 虛擬機的 IP 地址是什麼？
A: 在虛擬機中運行 `hostname -I` 獲取 IP 地址。

## 故障排除

如果遇到問題，請嘗試以下步驟：

1. 檢查 Apache 服務狀態：
```bash
sudo systemctl status apache2
```

2. 檢查 Apache 錯誤日誌：
```bash
sudo tail -f /var/log/apache2/error.log
```

3. 驗證防火牆規則：
```bash
sudo ufw status
```

4. 確認網絡連接：
```bash
ip addr show
```

5. 測試本地連接：
```bash
curl -v http://localhost
``` 