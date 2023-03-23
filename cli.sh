#!/usr/bin/env bash

#### MCSManager Command Line Interface
#### Made by BlueFunny

#### Copyright © 2023 MCSManager All rights reserved.

### Variables
## Files
mcsmPath="/opt/mcsmanager"
daemonPath="$mcsmPath/daemon"
webPath="$mcsmPath/web"

## Installed status
daemonInstalled=0
webInstalled=0
status=0

## Running status
daemonRunning=0
webRunning=0

## Language
if [ "$(echo "$LANG" | grep "zh_CN")" != "" ]; then
    zh=1
else
    zh=0
fi

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
        
        # No color echo
        *)
            [ "$zh" == 1 ] && echo "$2"
            [ "$zh" == 0 ] && echo "$3"
        ;;
    esac
    return
}

## Check the user is root
CheckRoot() {
    if [ "$(whoami)" != "root" ]; then
        LEcho error "请使用 root 用户执行此命令" "Please run this command as root"
    fi
    return
}

## Check mcsmanager installtion status
CheckInstall() {
    if [ -d "$daemonPath" ]; then
        daemonInstalled=1
    fi
    if [ -d "$webPath" ]; then
        webInstalled=1
    fi
    if [ $daemonInstalled == 1 ] && [ $webInstalled == 0 ] ;then
        status=1
        return
        elif [ $daemonInstalled == 0 ] && [ $webInstalled == 1 ];then
        status=2
        return
        elif [ $daemonInstalled == 1 ] && [ $webInstalled == 1 ];then
        status=3
        return
    fi
    LEcho error "[x] MCSManager 已损坏, 请尝试使用修复命令修复环境" "[x] MCSManager is broken, please try to use the repair command to repair the environment"
}

## Check mcsmanager running status
CheckRun() {
    if [ "$(systemctl is-active mcsm-web)" == "active" ];then
        webRunning=1
    fi
    if [ "$(systemctl is-active mcsm-daemon)" == "active" ];then
        daemonRunning=1
    fi
    return
}

## Check
CheckMCSM() {
    CheckInstall
    CheckRun
}

## GUI
GUI() {
    LEcho yellow "===============================================" "==============================================="
    LEcho cyan   "MCSManager 命令行                       v 1.0  " "MCSManager Command Line Interface       v 1.0  "
    LEcho yellow "===============================================" "==============================================="
    LEcho cyan_n "(1) 启停管理"                                    "(1) Start/Stop Control"
    LEcho cyan   "(2) 修复 MCSManager"                             "(2) Repair MCSManager"
    LEcho cyan   "(3) 检查 MCSManager 更新"                        "(3) Check MCSManager update"
    LEcho cyan   "(4) 清理 MCSManager 日志"                        "(4) Clean MCSManager log"
    LEcho cyan   "(5) 退出"                                        "(5) Exit"
    LEcho yellow "===============================================" "==============================================="
    LEcho cyan_n "请输入选项: "                                    "Please enter an option: "
    read -r option
    case $option in
        1)
            StartStop
        ;;
        2)
            Repair
        ;;
        3)
            CheckUpdate
        ;;
        4)
            CleanLog
        ;;
        5)
            exit 0
        ;;
        *)
            LEcho error "[x] 无效的选项, 请纠正输入" "[x] Invalid option, please correct the input"
        ;;
    esac
    LEcho error "[x] 未知错误, 请尝试使用修复命令修复环境" "[x] Unknown error, please try to use the repair command to repair the environment"
}

## Start/Stop control
StartStop() {
    LEcho yellow "===============================================" "==============================================="
    [ $status = 1 ] && LEcho cyan_n "当前 MCSManager 控制面板状态:" "Current MCSManager web panel status:"
    [ $webRunning = 0 ] && LEcho red " 已停止" " Stopped"
    [ $webRunning = 1 ] && LEcho green " 正在运行中" " Running"
    [ $status = 2 ] && LEcho cyan_n "当前 MCSManager 守护程序状态:" "Current MCSManager daemon status:"
    [ $daemonRunning = 0 ] && LEcho red " 已停止" " Stopped"
    [ $daemonRunning = 1 ] && LEcho green " 正在运行中" " Running"
    LEcho yellow "===============================================" "==============================================="
    LEcho cyan_n "(1) 启动/重启"                                        "(1) Start / Restart"
    [ $status = 1 ] && LEcho cyan "控制面板" "web panel"
    [ $status = 2 ] && LEcho cyan "守护程序" "daemon"
    [ $status = 3 ] && LEcho cyan "控制面板 & 守护程序" "web panel & daemon"
    LEcho cyan_n "(2) 停止"                                        "(2) Stop"
    [ $status = 1 ] && LEcho cyan "控制面板" "web panel"
    [ $status = 2 ] && LEcho cyan "守护程序" "daemon"
    [ $status = 3 ] && LEcho cyan "控制面板 & 守护程序" "web panel & daemon"
    LEcho cyan   "(3) 启用"                                        "(3) Enable"
    [ $status = 1 ] && LEcho cyan "控制面板" "web panel"
    [ $status = 2 ] && LEcho cyan "守护程序" "daemon"
    [ $status = 3 ] && LEcho cyan "控制面板 & 守护程序" "web panel & daemon"
    LEcho cyan   "(4) 禁用"                                        "(4) Disable"
    [ $status = 1 ] && LEcho cyan "控制面板" "web panel"
    [ $status = 2 ] && LEcho cyan "守护程序" "daemon"
    [ $status = 3 ] && LEcho cyan "控制面板 & 守护程序" "web panel & daemon"
    LEcho cyan   "(5) 返回"                                        "(4) Back"
    LEcho yellow "===============================================" "==============================================="
    LEcho cyan_n "请输入选项: "                                    "Please enter an option: "
    read -r option
    case $option in
        1)
            if [ "$status" = 1 ]; then
                systemctl restart mcsm-web || LEcho error "[x] 控制面板启动失败" "[x] Web panel start failed"
                elif [ "$status" = 2 ]; then
                systemctl restart mcsm-daemon || LEcho error "[x] 守护程序启动失败" "[x] Daemon start failed"
                elif [ "$status" = 3 ]; then
                systemctl restart mcsm-web || LEcho error "[x] 控制面板 & 守护程序启动失败" "[x] Web panel & daemon start failed"
                systemctl start mcsm-daemon || LEcho error "[x] 控制面板 & 守护程序启动失败" "[x] Web panel & daemon start failed"
            fi
            LEcho green "[√] 启动成功" "[√] Start successfully"
            sleep 3
            StartStop
        ;;
        2)
            if [ "$status" = 1 ]; then
                systemctl stop mcsm-web || LEcho error "[x] 控制面板停止失败" "[x] Web panel stop failed"
                elif [ "$status" = 2 ]; then
                systemctl stop mcsm-daemon || LEcho error "[x] 守护程序停止失败" "[x] Daemon stop failed"
                elif [ "$status" = 3 ]; then
                systemctl stop mcsm-web || LEcho error "[x] 控制面板 & 守护程序停止失败" "[x] Web panel & daemon stop failed"
                systemctl stop mcsm-daemon || LEcho error "[x] 控制面板 & 守护程序停止失败" "[x] Web panel & daemon stop failed"
            fi
            LEcho green "[√] 停止成功" "[√] Stop successfully"
            sleep 3
            StartStop
        ;;
        3)
            if [ "$status" = 1 ]; then
                systemctl enable mcsm-web || LEcho error "[x] 控制面板启用失败" "[x] Web panel enable failed"
                elif [ "$status" = 2 ]; then
                systemctl enable mcsm-daemon || LEcho error "[x] 守护程序启用失败" "[x] Daemon enable failed"
                elif [ "$status" = 3 ]; then
                systemctl enable mcsm-web || LEcho error "[x] 控制面板 & 守护程序启用失败" "[x] Web panel & daemon enable failed"
                systemctl enable mcsm-daemon  || LEcho error "[x] 控制面板 & 守护程序启用失败" "[x] Web panel & daemon enable failed"
            fi
            LEcho green "[√] 启用成功" "[√] Enable successfully"
            sleep 3
            StartStop
        ;;
        4)
            if [ "$status" = 1 ]; then
                systemctl disable mcsm-web || LEcho error "[x] 控制面板禁用失败" "[x] Web panel disable failed"
                elif [ "$status" = 2 ]; then
                systemctl disable mcsm-daemon || LEcho error "[x] 守护程序禁用失败" "[x] Daemon disable failed"
                elif [ "$status" = 3 ]; then
                systemctl disable mcsm-web || LEcho error "[x] 控制面板 & 守护程序禁用失败" "[x] Web panel & daemon disable failed"
                systemctl disable mcsm-daemon || LEcho error "[x] 控制面板 & 守护程序禁用失败" "[x] Web panel & daemon disable failed"
            fi
            LEcho green "[√] 禁用成功" "[√] Disable successfully"
            sleep 3
            StartStop
        ;;
        5)
            GUI
        ;;
        *)
            LEcho error "[x] 无效的选项, 请纠正输入" "[x] Invalid option, please correct the input"
        ;;
    esac
    LEcho error "[x] 未知错误, 请尝试使用修复命令修复环境" "[x] Unknown error, please try to use the repair command to repair the environment"
}

ChangeUsername