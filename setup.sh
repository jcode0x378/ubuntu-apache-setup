#!/bin/bash
# 主設置腳本

echo "開始安裝 Apache 伺服器環境..."

# 檢查是否以 root 權限運行
if [ "$(id -u)" -ne 0 ]; then
    echo "請以 sudo 或 root 權限運行此腳本"
    exit 1
fi

# 運行 Apache 安裝腳本
echo "執行 Apache 安裝..."
bash ./scripts/install_apache.sh
if [ $? -ne 0 ]; then
    echo "Apache 安裝失敗，請查看錯誤信息"
    exit 1
fi

# 配置 Apache
echo "配置 Apache..."
bash ./scripts/configure_apache.sh
if [ $? -ne 0 ]; then
    echo "Apache 配置失敗，請查看錯誤信息"
    exit 1
fi

# 設置防火牆
echo "設置防火牆..."
bash ./scripts/setup_firewall.sh
if [ $? -ne 0 ]; then
    echo "防火牆設置失敗，請查看錯誤信息"
    exit 1
fi

# 配置網絡
echo "配置網絡..."
bash ./scripts/network_config.sh
if [ $? -ne 0 ]; then
    echo "網絡配置失敗，請查看錯誤信息"
    exit 1
fi

# 安裝 VirtualBox Guest Additions（選擇性）
echo ""
echo "是否要安裝 VirtualBox Guest Additions 以啟用複製貼上功能？(y/n)"
read -r install_ga

if [ "$install_ga" = "y" ] || [ "$install_ga" = "Y" ]; then
    echo "安裝 VirtualBox Guest Additions..."
    
    # 安裝必要的依賴包
    apt update
    apt install -y build-essential dkms linux-headers-$(uname -r)
    
    # 檢查是否有 Guest Additions CD 已掛載
    if [ -f /media/*/VBoxLinuxAdditions.run ]; then
        sh /media/*/VBoxLinuxAdditions.run
    elif [ -f /mnt/VBoxLinuxAdditions.run ]; then
        sh /mnt/VBoxLinuxAdditions.run
    else
        echo "請先掛載 VirtualBox Guest Additions CD。"
        echo "步驟："
        echo "1. 在 VirtualBox 菜單中選擇「設備」>「插入 Guest Additions CD 映像」"
        echo "2. 然後執行："
        echo "   sudo mount /dev/cdrom /mnt"
        echo "   sudo sh /mnt/VBoxLinuxAdditions.run"
        echo "   sudo reboot"
    fi
    
    echo "完成 VirtualBox Guest Additions 安裝後，請重新啟動虛擬機。"
    echo "要立即重新啟動嗎？(y/n)"
    read -r reboot_now
    if [ "$reboot_now" = "y" ] || [ "$reboot_now" = "Y" ]; then
        reboot
    fi
fi

# 手動啟用共享剪貼簿提示
echo ""
echo "============================================================"
echo "啟用主機與虛擬機之間的複製貼上功能："
echo "============================================================"
echo "1. 在 VirtualBox 菜單中選擇：「設備」>「共用剪貼簿」>「雙向」"
echo "2. 在 VirtualBox 菜單中選擇：「設備」>「拖放」>「雙向」"
echo "3. 如尚未安裝 Guest Additions：「設備」>「安裝 Guest Additions」"
echo "============================================================"

# 顯示完成信息
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "==================================================="
echo "安裝完成！Apache 伺服器已成功配置。"
echo "可以通過以下網址訪問網站："
echo "http://${IP_ADDRESS}"
echo "==================================================="
echo "如需檢查 Apache 服務狀態，請運行: sudo systemctl status apache2"
echo "如需查看 Apache 錯誤日誌，請運行: sudo tail -f /var/log/apache2/error.log"

# 測試連線並提供解決方案
echo ""
echo "正在測試 Apache 服務..."
if curl -s --head http://localhost | grep "200" > /dev/null; then
    echo "Apache 服務正常運行於本機。"
    
    # 測試本機與外部連接
    echo "請在主機瀏覽器中訪問：http://$IP_ADDRESS"
    echo "如果無法訪問，請檢查："
    echo "1. 虛擬機網絡設置（應為橋接模式）"
    echo "2. 主機防火牆設置（允許虛擬機 IP 訪問）"
    echo "3. 嘗試重啟虛擬機和 Apache 服務：sudo systemctl restart apache2"
else
    echo "警告：Apache 服務在本機測試失敗。"
    echo "嘗試修復 Apache："
    systemctl restart apache2
    echo "請檢查 Apache 錯誤日誌：sudo tail -f /var/log/apache2/error.log"
fi

# 顯示持久化運行的資訊
echo ""
echo "==================================================="
echo "Apache 伺服器已設置為開機自動啟動"
echo "==================================================="
echo "重要提示：Apache 伺服器將在系統啟動時自動運行，"
echo "無需每次重新啟動虛擬機後手動啟動。"
echo ""
echo "如果 Apache 未能自動啟動，可以運行以下命令修復："
echo "sudo ./scripts/fix_apache.sh"
echo "===================================================" 