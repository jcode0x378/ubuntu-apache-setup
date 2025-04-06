# Ubuntu LAMP 環境快速啟動指南

此文件提供快速啟動和使用 LAMP 環境的基本步驟。

## 快速安裝

一行指令安裝全部環境：

```bash
sudo apt update && sudo apt install -y git && git clone https://github.com/yourusername/ubuntu-apache-setup.git && cd ubuntu-apache-setup && chmod +x setup.sh scripts/*.sh && sudo ./setup.sh
```

## 安裝後訪問

成功安裝後，您可以通過以下方式訪問：

- **主頁**: http://[伺服器IP]/
- **管理介面**: http://[伺服器IP]/admin.php
- **phpMyAdmin**: http://[伺服器IP]/phpmyadmin

## 管理員登入

- **用戶名**: admin
- **密碼**: demo

## 常用指令

### 重啟服務

```bash
# 重啟 Apache
sudo systemctl restart apache2

# 重啟 MariaDB
sudo systemctl restart mariadb
```

### 查看日誌

```bash
# Apache 錯誤日誌
sudo tail -f /var/log/apache2/error.log

# MariaDB 日誌
sudo tail -f /var/log/mysql/error.log
```

### 修復腳本

如果遇到 Apache 問題，可以執行修復腳本：

```bash
sudo ./scripts/fix_apache.sh
```

## 系統要求

- Ubuntu 伺服器 (推薦 20.04 LTS 或更高版本)
- 至少 1GB RAM
- 至少 10GB 硬碟空間
- 網路連接

## 安全建議

在生產環境中：

1. 立即更改所有預設密碼
2. 啟用 HTTPS
3. 調整檔案權限
4. 定期更新系統 