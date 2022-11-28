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
nodeVersion="14.19.1"
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
    CheckCN
    CheckNodejs

    LEcho cyan "[-] 环境初始化完成" "[-] Environment initialization completed"
    return
}

## Check if MCSM is installed
CheckMCSM() {
    if [ -d ${mcsmOldPath} ]; then
        LEcho yellow "[-] 检测到已安装的 MCSManager, 切换为更新模式..." "[-] MCSManager has been installed, switching to update mode..."

        # Switch to update mode
        installMode="upgrade"

        # Move old MCSM to backup path
        mv -f ${mcsmOldPath} ${mcsmOldPath}.bak

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
    LEcho cyan "=============== Node Version ===============" "=============== Node Version ==============="
    LEcho cyan "Node 版本: $(${node} --version)" "Node Version: $(${node} --version)"
    LEcho cyan "NPM 版本: $(${npm} --version)" "NPM Version: $(${npm} --version)"
    LEcho cyan "============================================" "============================================"
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
        mv -f ${mcsmOldPath}.bak/daemon/data/ ${mcsmPath}/daemon/data/
        mv -f ${mcsmOldPath}.bak/web/data/ ${mcsmPath}/web/data/
        if [ ! -d ${mcsmPath}/daemon/data/ ] || [ ! -d ${mcsmPath}/web/data/ ]; then
            LEcho yellow "[!] 部分数据迁移失败, 您可能需要到 ${mcsmOldPath}.bak 手动进行迁移" "[!] Some data migration failed, you may need to manually migrate to ${mcsmOldPath}.bak"
        fi
        LEcho green "[√] 数据迁移完成" "[√] Data migration completed"
    fi
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

    # Check install mode
    if [ ${mcsmOldPath} == "upgrade" ]; then
        LEcho cyan "[-] 检测到旧版 MCSManager 备份, 自动恢复中" "[-] Old version of MCSManager backup detected, automatic recovery"
        if ! mv -f ${mcsmOldPath}.bak ${mcsmOldPath}; then
            LEcho yellow "[!] 旧版 MCSManager 备份文件移动失败, 请手动移动 ${mcsmOldPath}.bak 至 ${mcsmOldPath}" "[!] Old version of MCSManager backup file move failed, please manually move ${mcsmOldPath}.bak to ${mcsmOldPath}"
        else
            rm -rf ${mcsmOldPath}.bak
        fi
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
+----------------------------------------------------------------------
" "+----------------------------------------------------------------------
| MCSManager Installer
+----------------------------------------------------------------------
| Copyright © 2022 MCSManager All rights reserved.
+----------------------------------------------------------------------
| Shell Install Script by Nuomiaa & CreeperKong
+----------------------------------------------------------------------
"
## Try to cheat APT
Init
Install
exit 0
