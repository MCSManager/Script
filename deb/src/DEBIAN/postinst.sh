#!/usr/bin/env bash

#### MCSM Install Script
#### Made By nuomiaa, CreeperKong, unitwk
#### Remake By BlueFunny_

### Variables ###
## Files
mcsmPath="/opt/mcsmanager"
nodePath="${mcsmPath}/node"

## Node
node="${nodePath}/bin/node"

## Language
if [ "$(locale -a | grep "zh_CN")" != "" ]; then
    zh=1
    export LANG="zh_CN.UTF-8"
else
    zh=0
fi

## Install Mode
if [ -d /tmp/mcsmanager/data ]; then
    installMode="upgrade"
else
    installMode="install"
fi

## Other
#firewall=""

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

### Main ###
Start() {
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

### Start ###
Start
exit 0
