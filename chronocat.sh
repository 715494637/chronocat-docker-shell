#!/bin/bash

# 添加颜色变量
RED="\e[31m"           # 红色
GREEN="\e[32m"         # 绿色
YELLOW="\e[33m"        # 黄色
RESET="\e[0m"          # 重置颜色

# 添加函数以显示不同颜色的消息
print_message() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${RESET}"
}

# 函数：检查端口是否合法且被占用
check_port() {
    local port=$1
    
    # 检查端口是否是一个正整数
    if ! [[ $port =~ ^[0-9]+$ ]]; then
        print_message "错误：端口号必须是一个正整数。" "$RED"
        exit 1
    fi
    
    # 检查端口范围
    if [ $port -lt 1 ] || [ $port -gt 65535 ]; then
        print_message "错误：端口号必须在 1-65535 之间。" "$RED"
        exit 1
    fi
    
    # 检查端口是否被占用
    ss -nlt | awk '{print $4}' | grep -q ":$port$"
    if [ $? -eq 0 ]; then
        print_message "错误：端口号 $port 已被占用。" "$RED"
        exit 1
    fi
    
    # 检查非安全端口
    if [ $port -lt 1024 ]; then
        print_message "警告：端口号 $port 不是安全端口。" "$YELLOW"
    fi
}

# 获取用户输入的端口号
read -p "请输入noVNC服务端口号(6080): " port1
read -p "请输入Red服务端口号(15360): " port2
read -p "请输入Satori服务端口号(5500): " port3

# 检查输入是否为空，如果为空则使用默认值
if [[ -z "$port1" ]]; then
  port1=6080
fi

if [[ -z "$port2" ]]; then
  port2=15360
fi

if [[ -z "$port3" ]]; then
  port3=5500
fi

# 检查端口号是否合法且被占用
check_port $port1
check_port $port2
check_port $port3

# 将端口号赋值给变量
VNCPORT=$port1
RedPORT=$port2
SatoriPORT=$port3

print_message "端口号检查完成" "$GREEN"

# 检查是否安装 Docker
if ! command -v docker &> /dev/null; then
    print_message "未检测到 Docker 环境，开始安装 Docker..." "$YELLOW"

    if command -v apt &> /dev/null; then
        apt update > /dev/null
        apt install -y docker.io > /dev/null
    elif command -v apt-get &> /dev/null; then
        apt-get update > /dev/null
        apt-get install -y docker.io > /dev/null
    elif command -v dnf &> /dev/null; then
        dnf install -y docker > /dev/null
        systemctl enable --now docker > /dev/null
    elif command -v yum &> /dev/null; then
        yum install -y docker-ce > /dev/null
        systemctl enable --now docker > /dev/null
    elif command -v pacman &> /dev/null; then
        pacman -Syu --noconfirm docker > /dev/null
        systemctl enable --now docker > /dev/null
    else
        print_message "无法确定操作系统的包管理器，请手动安装 Docker" "$RED"
        exit 1
    fi
    print_message "Docker 环境安装完成" "$GREEN"
else
    print_message "已安装 Docker 环境，跳过安装" "$GREEN"
fi

print_message "正在拉取 ChronoCat 镜像..." "$YELLOW"

docker pull he0119/chronocat-docker

read -p "请输入容器名称: " container_name
read -p "请输入VNC服务密码: " password

# 检查密码是否为空，如果为空则使用默认密码
if [ -z "$password" ]; then
  password="password"
fi

# 检查容器名称是否为空，如果为空则生成一个随机名称
if [ -z "$container_name" ]; then
  container_name=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8 ; echo '')
fi

print_message "=========================" "$GREEN"
echo -e "\033[32mnoVNC服务端口号:\033[0m \033[31m$VNCPORT\033[0m"
echo -e "\033[32mRed服务端口号:\033[0m \033[31m$RedPORT\033[0m"
echo -e "\033[32mSatori服务端口号:\033[0m \033[31m$SatoriPORT\033[0m"
echo -e "\033[32mVNC服务密码:\033[0m \033[31m$password\033[0m"
echo -e "\033[32m容器名称:\033[0m \033[31m$container_name\033[0m"
print_message "=========================" "$GREEN"

# 等待用户确认
read -p "请确认以上信息是否正确？[Y/n] " confirm
if [[ $confirm != "Y" && $confirm != "y" ]]; then
    print_message "用户取消操作，退出脚本。" "$RED"
    exit 1
fi

# 获取公网 IP
ip=$(curl -s https://api.ipify.org)

# 拼接 VNC 链接
vnc_link="http://$ip:$VNCPORT/"

print_message "正在启动 ChronoCat 容器..." "$YELLOW"

# 静默启动容器
docker run -it -p $RedPORT:16530 -p $VNCPORT:80 -p $SatoriPORT:5901 -e VNC_PASSWD=$password --name $container_name he0119/chronocat-docker > /dev/null

print_message "ChronoCat 容器启动完成" "$GREEN"

# 等待用户VNC操作完成
read -p "请在浏览器中打开VNC链接：$vnc_link，登录NTQQ后，按下回车键继续。" confirm

# cat抓取容器中/wine/drive_c/users/root/.chronocat/config/config.yaml文件
docker exec -it $container_name cat /wine/drive_c/users/root/.chronocat/config/config.yaml > config.yaml