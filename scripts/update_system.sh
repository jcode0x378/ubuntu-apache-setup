#!/bin/bash

# 確保腳本以 root 權限運行
if [ "$(id -u)" != "0" ]; then
   echo "此腳本需要 root 權限運行" 1>&2
   exit 1
fi

# 更新套件索引
echo "更新套件索引..."
apt update

# 安裝基本套件
echo "安裝基本系統工具..."
apt install -y \
  curl \
  wget \
  nano \
  git \
  zip \
  unzip \
  htop \
  net-tools \
  software-properties-common

# 升級已安裝的套件
echo "升級已安裝的套件..."
apt upgrade -y

# 安裝開發工具(如果有需要)
echo "安裝開發工具..."
apt install -y \
  build-essential \
  libssl-dev \
  libffi-dev

# 清理不需要的套件
echo "清理不需要的套件..."
apt autoremove -y
apt autoclean

echo "系統更新完成"
exit 0 