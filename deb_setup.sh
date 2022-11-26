#!/usr/bin/env bash

#### MCSM Install Script
#### Made By nuomiaa, CreeperKong, unitwk
#### Remake By BlueFunny_

### Variables ###

## Files
mcsmOldPath="/opt/mcsmanager"
mcsmPath="/opt/mcsmanager"
nodePath="${mcsmPath}/node"

## Node
nodeVersion="18.12.1"
node="${nodePath}/bin/node"
npm="${node} ${nodePath}/bin/npm"

## Install Mode
installMode="install"

## URL
daemonCloneURL="https://github.com/mcsmanager/MCSManager-Daemon-Production.git"
webCloneURL="https://github.com/mcsmanager/MCSManager-Web-Production.git"
nodeMirror="https://npmmirror.com/mirrors/node"

## Language
if [ "$(locale -a | grep "zh_CN")" != "" ]; then
    zh=1
    export LANG="zh_CN.UTF-8"
else
    zh=0
fi

## CDN
CN=0

## Other
try=1

### Tools ###
## Localize echo
LEcho() {
    case $1 in
    red)
        [ "${zh}" == 1 ] && printf '\033[1;31m%b\033[0m\n' "$2"
        [ "${zh}" == 0 ] && printf '\033[1;31m%b\033[0m\n' "$3"
        ;;
    green)
        [ "${zh}" == 1 ] && printf '\033[1;32m%b\033[0m\n' "$2"
        [ "${zh}" == 0 ] && printf '\033[1;32m%b\033[0m\n' "$3"
        ;;
    cyan)
        [ "${zh}" == 1 ] && printf '\033[1;36m%b\033[0m\n' "$2"
        [ "${zh}" == 0 ] && printf '\033[1;36m%b\033[0m\n' "$3"
        ;;
    cyan_n)
        [ "${zh}" == 1 ] && printf '\033[1;36m%b\033[0m' "$2"
        [ "${zh}" == 0 ] && printf '\033[1;36m%b\033[0m' "$3"
        ;;
    yellow)
        [ "${zh}" == 1 ] && printf '\033[1;33m%b\033[0m\n' "$2"
        [ "${zh}" == 0 ] && printf '\033[1;33m%b\033[0m\n' "$3"
        ;;
    error)
        Clean
        echo '================================================='
        [ "${zh}" == 1 ] && printf '\033[1;31;40m%b\033[0m\n' "$2"
        [ "${zh}" == 0 ] && printf '\033[1;31;40m%b\033[0m\n' "$3"
        echo '================================================='
        exit 1
        ;;
    *)
        [ "${zh}" == 1 ] && echo "$2"
        [ "${zh}" == 0 ] && echo "$3"
        ;;
    esac
    return
}

### Init ###
## Check environment
Init() {
    LEcho cyan "[-] 正在初始化环境..." "[-] Initializing environment..."

    # Check functions
    CheckMCSM
    CheckCommand
    CheckCN
    CheckNodejs

    LEcho cyan "[-] 环境初始化完成" "[-] Environment initialization completed"
    return
}

## Check if all necessary software is installed
CheckCommand() {
    LEcho cyan "[-] 正在检查依赖..." "[-] Checking dependencies..."

    # Check git
    if [[ $(command -v git) == "" ]]; then
        LEcho yellow "[-] 未安装 git" "[-] git is not installed"
        LEcho cyan "[-] 正在自动安装 git..." "[-] Automatically installing git..."
        [[ $(command -v apt) != "" ]] && apt install -y git
        [[ $(command -v yum) != "" ]] && yum install -y git
        [[ $(command -v pacman) != "" ]] && pacman -S git
        [[ $(command -v dnf) != "" ]] && dnf install -y git
        if [[ $(command -v git) == "" ]]; then LEcho error "[x] 未能自动安装 git, 请手动安装或重试" "[x] Unable to automatically install git, please manually install or try again"; fi
    fi

    # Check curl
    if [ "$(command -v curl)" == "" ]; then
        LEcho yellow "[-] 未安装 curl" "[-] curl is not installed"
        LEcho cyan "[-] 正在自动安装 curl..." "[-] Automatically installing curl..."
        [[ $(command -v apt) != "" ]] && apt install -y curl
        [[ $(command -v yum) != "" ]] && yum install -y curl
        [[ $(command -v pacman) != "" ]] && pacman -S curl
        [[ $(command -v dnf) != "" ]] && dnf install -y curl
        if [[ $(command -v curl) == "" ]]; then LEcho error "[x] 未能自动安装 curl, 请手动安装或重试" "[x] Unable to automatically install curl, please manually install or try again"; fi
    fi

    # Check wget
    if [ "$(command -v wget)" == "" ]; then
        LEcho yellow "[-] 未安装 wget" "[-] wget is not installed"
        LEcho cyan "[-] 正在自动安装 wget..." "[-] Automatically installing wget..."
        [[ $(command -v apt) != "" ]] && apt install -y wget
        [[ $(command -v yum) != "" ]] && yum install -y wget
        [[ $(command -v pacman) != "" ]] && pacman -S wget
        [[ $(command -v dnf) != "" ]] && dnf install -y wget
        if [[ $(command -v wget) == "" ]]; then LEcho error "[x] 未能自动安装 wget, 请手动安装或重试" "[x] Unable to automatically install wget, please manually install or try again"; fi
    fi

    # Check tar
    if [ "$(command -v tar)" == "" ]; then
        LEcho yellow "[-] 未安装 tar" "[-] tar is not installed"
        LEcho cyan "[-] 正在自动安装 tar..." "[-] Automatically installing tar..."
        [[ $(command -v apt) != "" ]] && apt install -y tar
        [[ $(command -v yum) != "" ]] && yum install -y tar
        [[ $(command -v pacman) != "" ]] && pacman -S tar
        [[ $(command -v dnf) != "" ]] && dnf install -y tar
        if [[ $(command -v tar) == "" ]]; then LEcho error "[x] 未能自动安装 tar, 请手动安装或重试" "[x] Unable to automatically install tar, please manually install or try again"; fi
    fi

    # Check npm
    if [ "$(command -v npm)" == "" ]; then
        LEcho yellow "[-] 未安装 npm" "[-] npm is not installed"
        LEcho cyan "[-] 正在自动安装 npm..." "[-] Automatically installing npm..."
        [[ $(command -v apt) != "" ]] && apt install -y npm
        [[ $(command -v yum) != "" ]] && yum install -y npm
        [[ $(command -v pacman) != "" ]] && pacman -S npm
        [[ $(command -v dnf) != "" ]] && dnf install -y npm
        if [[ $(command -v npm) == "" ]]; then LEcho error "[x] 未能自动安装 npm, 请手动安装或重试" "[x] Unable to automatically install npm, please manually install or try again"; fi
    fi

    LEcho cyan "[-] 依赖检查完成" "[-] Dependency check completed"
    return
}

## Check if MCSM is installed
CheckMCSM() {
    if [ -d ${mcsmOldPath} ]; then
        LEcho yellow "[-] 检测到已安装的 MCSManager, 切换为更新模式..." "[-] MCSManager has been installed, switching to update mode..."

        # Switch to update mode
        installMode="upgrade"

        # Prepare for backup old data
        mkdir -p /tmp/mcsmanager/data

        # A little easteregg
        # Maybe you wanna play Inscryption?
        LEcho cyan "[-] 正在将 旧数据 打包并移动至临时文件夹..." "[-] Packing and moving old data to temporary folder..."

        # Backup old data
        if [ -d ${mcsmOldPath}/daemon/data ]; then
            mv -f ${mcsmOldPath}/daemon/data /tmp/mcsmanager/data/daemon
        else
            LEcho yellow "[-] 未检测到旧版 Daemon 数据, 跳过迁移..." "[-] Old Daemon data was not detected, skipping migration..."
        fi
        if [ -d ${mcsmOldPath}/web/data ]; then
            mv -f ${mcsmOldPath}/web/data /tmp/mcsmanager/data/web
        else
            LEcho yellow "[-] 未检测到旧版 Web 数据, 跳过迁移..." "[-] Old Web data was not detected, skipping migration..."
        fi

        # Remove old service
        if [ -f /etc/systemd/system/mcsm-daemon.service ]; then
            systemctl stop mcsm-daemon
            systemctl disable mcsm-daemon
            rm -f /etc/systemd/system/mcsm-daemon.service
        fi
        if [ -f /etc/systemd/system/mcsm-web.service ]; then
            systemctl stop mcsm-web
            systemctl disable mcsm-web
            rm -f /etc/systemd/system/mcsm-web.service
        fi
        systemctl daemon-reload

        # Remove old data
        if [ -d ${mcsmOldPath} ]; then
            rm -rf ${mcsmOldPath}
        fi

        # Remove old link
        if [ -L /usr/bin/mcsmanager ]; then
            rm -f /usr/bin/mcsmanager
        fi
    fi

    # Prepare for a new install
    mkdir -p ${nodePath}
    return
}

## Check if the system is Chinese
CheckCN() {
    if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
        LEcho yellow "[!] 根据 'ipapi.co' 提供的信息, 当前服务器可能在中国" "[!] According to the information provided by 'ipapi.co', the current server IP may be in China"
        [ "${zh}" == 1 ] && read -e -r -p "[?] 是否选用中国镜像完成安装? [y/n] " input
        [ "${zh}" == 0 ] && read -e -r -p "[?] Whether to use the Chinese mirror to complete the installation? [y/n] " input
        case ${input} in
        [yY][eE][sS] | [yY])
            LEcho cyan "[-] 选用中国镜像" "[-] Use Chinese mirror"
            CN=1
            ;;
        *)
            LEcho cyan "[-] 不选用中国镜像" "[-] Do not use Chinese mirror"
            ;;
        esac
    fi
    if [ "${CN}" == 1 ]; then
        daemonCloneURL="https://gitee.com/mcsmanager/MCSManager-Daemon-Production.git"
        webCloneURL="https://gitee.com/mcsmanager/MCSManager-Web-Production.git"
        export N_NODE_MIRROR=${nodeMirror}
    fi
    return
}

## Check nodejs
CheckNodejs() {
    if ! /usr/local/bin/n -V; then
        if [ "${CN}" == 1 ]; then
            npm i -g n --registry=https://registry.npmmirror.com
        else
            npm i -g n
        fi
    fi
    while true; do
        if /usr/local/bin/n ${nodeVersion} -q -d || [ ${try} == 3 ]; then
            break
        else
            LEcho yellow "[!] 安装 Node.js ${nodeVersion} 失败, 重试中... (${try}/3)" "[!] Failed to install Node.js ${nodeVersion}, retrying... (${try}/3)"
        fi
        sleep 3
        try=${try}+1
    done
    cp -r /usr/local/n/versions/node/${nodeVersion}/* ${nodePath}/
    /usr/local/bin/n rm ${nodeVersion}
    if ! ${node} --version; then
        LEcho error "[x] 未能成功安装最新版本 Node.js" "[x] Failed to install the latest version of Node.js"
    fi
    LEcho yellow "=============== Node Version ===============" "=============== Node Version ==============="
    LEcho yellow "Node 版本: $(${node} --version)" "Node Version: $(${node} --version)"
    LEcho yellow "NPM 版本: $(${npm} --version)" "NPM Version: $(${npm} --version)"
    LEcho yellow "============================================" "============================================"
    return
}

### Main ###
## Main Install Function
Install() {
    LEcho cyan "[-] 正在安装 MCSManager ..." "[-] Installing MCSManager ..."

    # Move to MCSM
    cd ${mcsmPath} || LEcho error "[x] 未能成功进入 MCSM 安装目录" "[x] Failed to enter the MCSM installation directory"

    # Download MCSM Daemon
    LEcho cyan "[↓] 正在下载 MCSManager Daemon..." "[↓] Downloading MCSManager Daemon..."
    git clone --single-branch -b master --depth 1 ${daemonCloneURL}
    mv -f MCSManager-Daemon-Production daemon

    # Download MCSM Web
    LEcho cyan "[↓] 正在下载 MCSManager Web..." "[↓] Downloading MCSManager Web..."
    git clone --single-branch -b master --depth 1 ${webCloneURL}
    mv -f MCSManager-Web-Production web

    # Install MCSM Daemon
    LEcho cyan "[+] 正在安装 MCSManager Daemon..." "[+] Installing MCSManager Daemon..."
    cd daemon || LEcho error "[x] 未能成功进入 MCSM Daemon 安装目录" "[x] Failed to enter the MCSM Daemon installation directory"
    if [ "${CN}" == 1 ]; then
        ${npm} i --registry=https://registry.npmmirror.com
    else
        ${npm} i
    fi

    # Install MCSM Web
    LEcho cyan "[+] 正在安装 MCSManager Web..." "[+] Installing MCSManager Web..."
    cd ../web || LEcho error "[x] 未能成功进入 MCSM Web 安装目录" "[x] Failed to enter the MCSManager Web installation directory"
    if [ "${CN}" == 1 ]; then
        ${npm} i --registry=https://registry.npmmirror.com
    else
        ${npm} i
    fi

    LEcho green "[√] MCSManager 安装完成" "[√] MCSManager installation completed"

    # Check install mode
    if [ "${installMode}" == "upgrade" ]; then
        LEcho cyan "[-] 正在移动旧数据..." "[-] Moving old data..."
        mv -f /tmp/mcsmanager/data/daemon ${mcsmPath}/daemon/data || LEcho yellow "[-] 未检测到旧版 Daemon 数据, 跳过迁移..." "[-] Old Daemon data was not detected, skipping migration..."
        mv -f /tmp/mcsmanager/data/web ${mcsmPath}/web/data || LEcho yellow "[-] 未检测到旧版 Web 数据, 跳过迁移..." "[-] Old Web data was not detected, skipping migration..."
        rm -rf /tmp/mcsmanager
        LEcho green "[√] 数据迁移完成" "[√] Data migration completed"
    fi
    LEcho cyan "[-] 正在注册系统服务..." "[-] Registering system service..."

    echo "
[Unit]
Description=MCSManager Daemon

[Service]
WorkingDirectory=/opt/mcsmanager/daemon
ExecStart=${node} app.js
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
Environment=\"PATH=${PATH}\"

[Install]
WantedBy=multi-user.target
" >/etc/systemd/system/mcsm-daemon.service

    echo "
[Unit]
Description=MCSManager Web

[Service]
WorkingDirectory=/opt/mcsmanager/web
ExecStart=${node} app.js
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
Environment=\"PATH=${PATH}\"

[Install]
WantedBy=multi-user.target
" >/etc/systemd/system/mcsm-web.service

    LEcho cyan "[-] 正在启动 MCSManager..." "[-] Starting MCSManager..."

    # Start MCSM service
    systemctl enable mcsm-daemon.service --now
    systemctl enable mcsm-web.service --now
    systemctl start mcsm-daemon.service
    systemctl start mcsm-web.service

    # Check MCSM service
    if ! systemctl is-active --quiet mcsm-daemon.service || ! systemctl --quiet is-active mcsm-web.service; then
        systemctl status mcsm-{web,daemon}.service
        LEcho error "[x] MCSManager 启动失败" "[x] MCSManager failed to start"
    fi

    # Allow ports
    if command -v ufw; then
        ufw allow 23333/tcp
        ufw allow 24444/tcp
    elif command -v iptables-save; then
        iptables -A INPUT -p tcp --dport 23333 -j ACCEPT
        iptables -A INPUT -p tcp --dport 24444 -j ACCEPT
        iptables-save
    #else
    #    firewall="problem"
    fi

    # Output auth information
    AuthInfo
    return
}

## Access Information
AuthInfo() {
    if [ ${installMode} == "upgrade" ]; then
        ip="$(curl -s https://ipconfig.io)"
        port=$(cat ${mcsmPath}/web/data/SystemConfig/config.json | grep "httpPort" | tr -cd '0-9')
        daemonPort=$(cat ${mcsmPath}/daemon/data/Config/global.json | grep "port" | tr -cd '0-9')
    fi
    LEcho cyan "==================================================================" "=================================================================="
    LEcho cyan "欢迎使用 MCSManager, 您可以通过以下方式访问 MCSManager " "Welcome to MCSManager, you can access it by the following ways"
    LEcho cyan "==================================================================" "=================================================================="
    LEcho cyan_n "控制面板地址: " "Web Service Address: "

    [ ${installMode} == "upgrade" ] && LEcho cyan "http://${ip}:${port}" "http://${ip}:${port}"
    [ ${installMode} == "upgrade" ] && LEcho yellow "若无法访问面板, 请检查 [云防火墙 / 安全组] 是否有放行面板 ${port} 和 ${daemonPort} 端口, 控制面板需要这两个端口才能正常工作" "You must expose ports ${port} and ${daemonPort} to use the service properly on the Internet."
    #[ ${installMode} == "upgrade" ] && [ ${firewall} == "problem" ] && LEcho red "您的服务器没有安装防火墙, 请自行放行面板 ${port} 和 ${daemonPort} 端口, 控制面板需要这两个端口才能正常工作" "Your server does not have a firewall installed, please expose ports ${port} and ${daemonPort} to use the service properly on the Internet."

    [ ${installMode} == "install" ] && LEcho cyan "http://localhost:23333" "http://localhost:23333"
    [ ${installMode} == "install" ] && LEcho yellow "若无法访问面板, 请检查 [云防火墙 / 安全组] 是否有放行面板 23333 和 24444 端口, 控制面板需要这两个端口才能正常工作" "You must expose ports 23333 and 24444 to use the service properly on the Internet."
    #[ ${installMode} == "install" ] && [ ${firewall} == "problem" ] && LEcho red "您的服务器没有安装防火墙, 请自行放行面板 23333 和 24444 端口, 控制面板需要这两个端口才能正常工作" "Your server does not have a firewall installed, please expose ports 23333 and 24444 to use the service properly on the Internet."

    LEcho cyan "更多使用说明, 请参考: https://docs.mcsmanager.com/" "More info: https://docs.mcsmanager.com/"
    LEcho cyan "==================================================================" "=================================================================="
    return
}

### Other ###
## Clean up
Clean() {
    # Remove service
    if [ -f /etc/systemd/system/mcsm-daemon.service ]; then
        systemctl is-active --quiet mcsm-daemon && systemctl stop mcsm-daemon
        systemctl disable mcsm-daemon
        rm -f /etc/systemd/system/mcsm-daemon.service
    fi
    if [ -f /etc/systemd/system/mcsm-web.service ]; then
        systemctl is-active --quiet mcsm-web && systemctl stop mcsm-web
        systemctl disable mcsm-web
        rm -f /etc/systemd/system/mcsm-web.service
    fi
    systemctl daemon-reload

    # Remove MCSManager
    if [ -d "${mcsmPath}" ]; then
        rm -rf "${mcsmPath}"
    fi
    return
}

### Start ###
LEcho cyan "+----------------------------------------------------------------------
| MCSManager Installer
+----------------------------------------------------------------------
| Copyright © 2022 MCSManager All rights reserved.
+----------------------------------------------------------------------
| Shell Install Script by Nuomiaa & CreeperKong
| Remake By BlueFunny_
+----------------------------------------------------------------------
" "+----------------------------------------------------------------------
| MCSManager Installer
+----------------------------------------------------------------------
| Copyright © 2022 MCSManager All rights reserved.
+----------------------------------------------------------------------
| Shell Install Script by Nuomiaa & CreeperKong
| Remake By BlueFunny_
+----------------------------------------------------------------------
"
## Try to cheat APT
Init
Install
exit 0
