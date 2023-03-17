#!/usr/bin/env bash

#### MCSManager Installer
#### Made by BlueFunny
#### Originally written by nuomiaa, CreeperKong, unitwk

#### Copyright © 2023 MCSManager All rights reserved.

### Variables
## Files
# MCSManager
mcsmPath="/opt/mcsmanager"
daemonPath="$mcsmPath/daemon"
webPath="$mcsmPath/web"

# Node.js
nodePath="$mcsmPath/node"
nodeBin="$nodePath/bin/node"
npmBin="$nodePath/bin/npm"

# Junk
tmpDir="/tmp/mcsmanager"

## Node info
nodeVer="v16.13.0"

## Install mode
mode="install"

## URLs
# Node.js
nodeBaseURL="https://nodejs.org/dist"
nodeFileURL="$nodeBaseURL/$nodeVer/node-$nodeVer-linux-$arch.tar.gz"
nodeHashURL="$nodeBaseURL/$nodeVer/SHASUMS256.txt"

# MCSManager
daemonURL="https://github.com/mcsmanager/MCSManager-Daemon-Production.git"
webURL="https://github.com/mcsmanager/MCSManager-Web-Production.git"

## Language
if [ "$(echo "$LANG" | grep "zh_CN")" != "" ]; then
    zh=1
else
    zh=0
fi

## Systemd service command
webExecStart="\"$nodeBin\" \"$webPath/app.js\""
daemonExecStart="\"$nodeBin\" \"$daemonPath/app.js\""

## Debug
debug=0

## Other
cn=0

### Functions
## Localize echo
# $1: color
# $2: zh
# $3: en
LEcho() {
    case $1 in
        # Red color echo
        red)
            [ "${zh}" == 1 ] && printf '\033[1;31m%b\033[0m\n' "$2"
            [ "${zh}" == 0 ] && printf '\033[1;31m%b\033[0m\n' "$3"
        ;;
        
        # Green color echo
        green)
            [ "${zh}" == 1 ] && printf '\033[1;32m%b\033[0m\n' "$2"
            [ "${zh}" == 0 ] && printf '\033[1;32m%b\033[0m\n' "$3"
        ;;
        
        # Cyan color echo
        cyan)
            [ "${zh}" == 1 ] && printf '\033[1;36m%b\033[0m\n' "$2"
            [ "${zh}" == 0 ] && printf '\033[1;36m%b\033[0m\n' "$3"
        ;;
        
        # Cyan color echo (No line break)
        cyan_n)
            [ "${zh}" == 1 ] && printf '\033[1;36m%b\033[0m' "$2"
            [ "${zh}" == 0 ] && printf '\033[1;36m%b\033[0m' "$3"
        ;;
        
        # Yellow color echo
        yellow)
            [ "${zh}" == 1 ] && printf '\033[1;33m%b\033[0m\n' "$2"
            [ "${zh}" == 0 ] && printf '\033[1;33m%b\033[0m\n' "$3"
        ;;
        
        # Red error echo
        error)
            Clean
            echo '================================================='
            [ "$zh" == 1 ] && printf '\033[1;31;40m%b\033[0m\n' "$2"
            [ "$zh" == 0 ] && printf '\033[1;31;40m%b\033[0m\n' "$3"
            echo '================================================='
            exit 1
        ;;
        
        # Debug echo
        debug)
            [ "$debug" == 1 ] && printf '\033[1;35m%b\033[0m\n' "[DEBUG] $2"
        ;;
        
        # No color echo
        *)
            [ "$zh" == 1 ] && echo "$2"
            [ "$zh" == 0 ] && echo "$3"
        ;;
    esac
    return
}

## Check root
CheckRoot() {
    if [[ $EUID -ne 0 ]]; then
        LEcho debug "User: $(whoami)"
        LEcho debug "EUID: $EUID"
        LEcho error "[!] 请使用 root 用户运行此脚本" "[!] Please run this script as root"
    fi
    return
}

## Detect server geographic location
CheckCN() {
    LEcho echo "[*] 正在检查服务器地理位置" "[*] Checking server location"
    if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
        LEcho yellow "[!] 根据 'ipapi.co' 提供的信息, 当前服务器可能在中国, 已自动切换为中国镜像源" "[!] According to the information provided by 'ipapi.co', the current server IP may be in China, and the Chinese mirror source has been automatically switched"
        LEcho debug "=============================================="
        LEcho debug "Raw data: $(curl -m 10 -s https://ipapi.co/json)"
        LEcho debug "=============================================="
        daemonURL="https://gitee.com/mcsmanager/MCSManager-Daemon-Production.git"
        webURL="https://gitee.com/mcsmanager/MCSManager-Web-Production.git"
        nodeBaseURL="https://npmmirror.com/mirrors/node"
        cn=1
    else
        LEcho cyan "[-] 检测服务器地理位置出错, 跳过检测" "[-] Error detecting server location, skipping detection"
    fi
    return
}

## Detect system architecture
CheckArch() {
    LEcho echo "[*] 正在检查系统架构" "[*] Checking system architecture"
    LEcho debug "Raw architecture: $arch"
    arch=$(uname -m)
    case $arch in
        x86_64)
            arch="x64"
        ;;
        aarch64)
            arch="arm64"
        ;;
        arm)
            arch="armv7l"
        ;;
        ppc64le)
            arch="ppc64le"
        ;;
        s390x)
            arch="s390x"
        ;;
        *)
            LEcho error "[x] MCSManager 暂不支持当前系统架构" "[x] MCSManager does not currently support the current system architecture"
        ;;
    esac
    return
}

## Detect system version
CheckOS() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        LEcho debug "========================================"
        LEcho debug "Raw data: $(cat /etc/os-release)"
        LEcho debug "========================================"
        case "$ID" in
            debian|ubuntu)
                os="debian"
            ;;
            centos|rhel|fedora)
                os="redhat"
            ;;
            *)
                LEcho error "[x] 本脚本仅支持 Ubuntu/Debian/CentOS 系统!" "[x] This script only supports Ubuntu/Debian/CentOS systems!"
            ;;
        esac
    else
        LEcho error "[x] 未能正常检测到系统类型, 无法继续安装" "[x] Unable to detect system type, installation cannot continue"
    fi
    return
}

## Detect nodejs version
CheckNode() {
    if command -v node > /dev/null; then
        if [ "$(node -v | cut -c2- | awk -F. '{print $1}')" -ge 14 ]; then
            return 0
        fi
    fi
    return 1
}

## Main GUI
GUI(){
    clear
    LEcho cyan "===============================================" "==============================================="
    LEcho cyan "MCSManager Installer"                            "MCSManager Installer"
    LEcho cyan "===============================================" "==============================================="
    LEcho cyan "1. 安装 MCSManager"                               "1. Install MCSManager"
    LEcho cyan "2. 卸载 MCSManager"                               "2. Uninstall MCSManager"
    LEcho cyan "3. 退出"                                          "3. Exit"
    LEcho cyan "===============================================" "==============================================="
    LEcho cyan_n "请输入选项: " "Please enter an option: "
    read -r option
    case $option in
        1)
            Install
        ;;
        2)
            Remove
        ;;
        3)
            return
        ;;
        *)
            LEcho error "[x] 无效的选项" "[x] Invalid option"
            GUI
        ;;
    esac
    return
}

## Install MCSManager
Install() {
    clear
    LEcho cyan "[-] 开始安装 MCSManager" "[-] Start installing MCSManager"
    # Init work environment
    LEcho cyan "[*] 正在初始化工作环境" "[*] Initializing work environment"
    mkdir -p $tmpDir
    
    # Detect old MCSManager
    [ -d $mcsmPath ] && LEcho yellow "[!] 检测到旧版 MCSManager, 切换为更新模式" "[!] Old version of MCSManager detected, switch to update mode"
    [ -d $mcsmPath ] && mode="update"
    mkdir -p $mcsmPath
    
    # Install dependencies
    LEcho cyan "[*] 正在安装安装所需的工具" "[*] Installing the tools required for installation"
    if [ "$os" == "debian" ]; then
        apt-get update
        apt-get install -y curl git wget
        elif [ "$os" == "redhat" ]; then
        yum install -y curl git wget
    fi
    
    # Install nodejs
    if ! CheckNode;then
        LEcho cyan "[*] 正在安装 Node.js" "[*] Installing Node.js"
        # Download nodejs files
        wget -t=3 -q --no-check-certificate --show-progress -O $tmpDir/node.tar.gz "$nodeFileURL"
        wget -t=3 -q --no-check-certificate --show-progress -O $tmpDir/node.sha256 "$nodeHashURL"
        
        # Check nodejs files
        if [ "$(sha256sum $tmpDir/node.tar.gz | awk '{print $1}')" != "$(cat $tmpDir/node.sha256)" ]; then
            LEcho error "[x] Node.js 安装包校验失败, 请重试" "[x] Node.js installation package verification failed, please try again"
        fi
        
        # Install nodejs
        tar -xzf $tmpDir/node.tar.gz -C $tmpDir
        cp -r "$tmpDir/node-$nodeVer-linux-$arch/*" $nodePath
        
        LEcho cyan "===============================================" "==============================================="
        LEcho cyan "Node.js 版本: $($nodeBin --version)" "Node.js version: $($nodeBin --version)"
        LEcho cyan "NPM 版本: $($npmBin -v)" "NPM version: $($npmBin -v)"
        LEcho cyan "===============================================" "==============================================="
    else
        LEcho cyan "[-] 检测到已安装 Node.js, 跳过安装" "[-] Detected installed Node.js, skip installation"
        nodeBin="$(which node)"
        npmBin="$(which npm)"
    fi
    
    # Install MCSManager
    if [ $mode == "update" ];then
        LEcho cyan "[*] 正在更新 MCSManager 前端管理面板" "[*] Updating MCSManager web panel"
        
        cd $webPath || LEcho error "[x] 无法进入 MCSManager 前端管理面板目录, 请检查权限" "[x] Unable to enter MCSManager web panel directory, please check permissions"
        
        # Clone MCSManager web panel
        git remote set-url origin $webURL
        git fetch origin
        git checkout master
        git reset --hard origin/master
        git pull
        
        LEcho cyan "[*] 正在更新 MCSManager 守护晨曦股" "[*] Updating MCSManager daemon"
        
        cd $daemonPath || LEcho error "[x] 无法进入 MCSManager 守护程序目录, 请检查权限" "[x] Unable to enter MCSManager daemon directory, please check permissions"
        
        # Clone MCSManager daemon
        git remote set-url origin $daemonURL
        git fetch origin
        git checkout master
        git reset --hard origin/master
        git pull
    else
        # Clone MCSManager web panel
        LEcho cyan "[*] 正在安装 MCSManager 前端管理面板" "[*] Installing MCSManager web panel"
        git clone --single-branch -b master --depth 1 $webURL $webPath
        
        # Clone MCSManager daemon
        LEcho cyan "[*] 正在安装 MCSManager 守护程序" "[*] Installing MCSManager web panel"
        git clone --single-branch -b master --depth 1 $daemonURL $daemonPath
    fi
    # Update dependencies
    LEcho cyan "[*] 正在更新依赖" "[*] Updating dependencies"
    cd $webPath || LEcho error "[x] 无法进入 MCSManager 前端管理目录, 请检查权限" "[x] Unable to enter MCSManager web panel directory, please check permissions"
    [ $cn == 1 ] && $npmBin install --registry=https://registry.npmmirror.com
    [ $cn == 0 ] && $npmBin install
    cd $daemonPath || LEcho error "[x] 无法进入 MCSManager 守护程序目录, 请检查权限" "[x] Unable to enter MCSManager daemon directory, please check permissions"
    [ $cn == 1 ] && $npmBin install --registry=https://registry.npmmirror.com
    [ $cn == 0 ] && $npmBin install
    
    # Create systemd service
    LEcho cyan "[*] 正在创建 systemd 服务" "[*] Creating systemd service"
    cat > /etc/systemd/system/mcsm-web.service << EOF
    [Unit]
    Description=MCSManager Web Panel Service
    After=network.target

    [Service]
    User=root
    WorkingDirectory=\"$webPath\"
    ExecStart=$webExecStart
    Restart=always

    [Install]
    WantedBy=multi-user.target
EOF
    cat > /etc/systemd/system/mcsm-daemon.service << EOF
    [Unit]
    Description=MCSManager Daemon Service
    After=network.target

    [Service]
    User=root
    WorkingDirectory=\"$daemonPath\"
    ExecStart=$daemonExecStart
    Restart=always

    [Install]
    WantedBy=multi-user.target
EOF
    # Enable systemd service
    LEcho cyan "[*] 正在启动 MCSManager 服务" "[*] Starting MCSManager services"
    systemctl daemon-reload
    systemctl enable mcsm-web --now || LEcho error "[x] 无法启动 MCSManager 前端管理面板服务" "[x] Unable to start MCSManager web panel service"
    systemctl enable mcsm-daemon --now || LEcho error "[x] 无法启动 MCSManager 守护程序服务" "[x] Unable to start MCSManager daemon service"
    
    # Output login info
    LEcho green "[√] MCSManager 安装完毕" "[√] MCSManager installation completed"
    LEcho yellow "==================================================================" "=================================================================="
    LEcho green "欢迎使用 MCSManager, 您可以通过以下方式访问: " "Welcome to use MCSManager, you can access it through the following ways:"
    LEcho yellow "==================================================================" "=================================================================="
    LEcho cyan_n "控制面板地址：   " "Control panel address:   "
    LEcho yellow "http://localhost:23333" "http://localhost:23333"
    LEcho red "若无法访问面板，请检查防火墙/安全组是否有放行面板 23333 和 24444 端口，控制面板需要这两个端口才能正常工作。" "If you can't access the panel, please check if the firewall/security group has opened the panel 23333 and 24444 ports. The control panel needs these two ports to work properly."
    LEcho yellow "==================================================================" "=================================================================="
    LEcho cyan "重启 systemctl restart mcsm-{daemon,web}.service" "Restart systemctl restart mcsm-{daemon,web}.service"
    LEcho cyan "禁用 systemctl disable mcsm-{daemon,web}.service" "Disable systemctl disable mcsm-{daemon,web}.service"
    LEcho cyan "启用 systemctl enable mcsm-{daemon,web}.service" "Enable systemctl enable mcsm-{daemon,web}.service"
    LEcho cyan "启动 systemctl start mcsm-{daemon,web}.service" "Start systemctl start mcsm-{daemon,web}.service"
    LEcho cyan "停止 systemctl stop mcsm-{daemon,web}.service" "Stop systemctl stop mcsm-{daemon,web}.service"
    LEcho cyan "更多使用说明, 请参考: https://docs.mcsmanager.com/" "More usage instructions, please refer to: https://docs.mcsmanager.com/"
    LEcho yellow "==================================================================" "=================================================================="
    
    # Clean up
    rm -rf $tmpDir
    return
}

## Remove MCSManager
Remove() {
    clear
    LEcho yellow "==================================================================" "=================================================================="
    LEcho yellow "[!] 你确定要删除 MCSManager 吗" "[!] Are you sure you want to delete MCSManager"
    LEcho yellow "[!] 删除 MCSManager 后, 所有服务器数据将会丢失" "[!] All server data will be lost after deleting MCSManager"
    LEcho yellow "[!] 请在 10 秒内按下 Ctrl + C 取消删除" "[!] Please press Ctrl + C within 10 seconds to cancel deletion"
    LEcho yellow "==================================================================" "=================================================================="
    sleep 10
    
    LEcho cyan "[*] 正在停止 MCSManager 服务" "[*] Stopping MCSManager service"
    systemctl disable mcsm-daemon --now || LEcho error "[x] 无法停止 MCSManager 守护程序服务" "[x] Unable to stop MCSManager daemon service"
    systemctl disable mcsm-web --now || LEcho error "[x] 无法停止 MCSManager 前端管理面板服务" "[x] Unable to stop MCSManager web panel service"
    
    LEcho cyan "[*] 正在删除 MCSManager 服务" "[*] Deleting MCSManager service"
    rm -rf /etc/systemd/system/mcsm-daemon.service
    rm -rf /etc/systemd/system/mcsm-web.service
    systemctl daemon-reload
    
    LEcho cyan "[*] 正在删除 MCSManager 目录" "[*] Deleting MCSManager directory"
    rm -rf $mcsmPath
    
    LEcho green "[√] MCSManager 删除完毕" "[√] MCSManager deletion completed"
    return
}

## Clean up
Clean() {
    LEcho cyan "[*] 正在清理残余文件" "[*] Cleaning up"
    rm -rf $tmpDir
    [ $mode != "update" ] && rm -rf $mcsmPath
    return
}

### Start

LEcho echo "[-] 正在检查基础环境, 请稍等" "[-] Checking basic environment, please wait"
CheckRoot
CheckArch
CheckOS
CheckCN
GUI
LEcho cyan "[-] 期待与您的下次见面" "[-] Looking forward to seeing you again"