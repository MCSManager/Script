#!/usr/bin/env bash

#### MCSM Uninstall Script
#### Made By nuomiaa, CreeperKong, unitwk
#### Remake By BlueFunny_

### Variables ###
## Files
mcsmPath="/opt/mcsmanager"

## Language
if [ "$(locale -a | grep "zh_CN")" != "" ]; then
    zh=1
    export LANG="zh_CN.UTF-8"
else
    zh=0
fi

### Tools ###
# Localize echo
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
    LEcho cyan "[-] 正在卸载 MCSManager..." "[-] Uninstalling MCSManager..."

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

    LEcho green "[+] MCSManager 卸载成功！" "[+] MCSManager Uninstalled!"
    return
}

### Start ###
Start
exit 0