#!/usr/bin/env bash

#### MCSM Install Script
#### Made By nuomiaa, CreeperKong, unitwk
#### Recode By BlueFunny_

### Variables ###
## Files
mcsmPath="/opt/mcsmanager"
mcsmDaemonDPath="${mcsmPath}/daemon/data"
mcsmWebDPath="${mcsmPath}/web/data"
nodePath="${mcsmPath}/node"
tmpPath="/tmp/mcsmanager-setup"

## Node
nodeVersion="v14.19.1"
node="${nodePath}/bin/node"
npm="${nodePath}/bin/npm"

## Setup tools mode
mode="install"

## URL
nodeMirror="https://nodejs.org/dist"
daemonCloneURL="https://github.com/mcsmanager/MCSManager-Daemon-Production.git"
webCloneURL="https://github.com/mcsmanager/MCSManager-Web-Production.git"
nodeFileURL="${nodeMirror}/${nodeVersion}/node-${nodeVersion}-linux-${arch}.tar.gz"
nodeHashURL="${nodeMirror}/${nodeVersion}/SHASUMS256.txt"

## Language
if [ "$(locale -a | grep "zh_CN")" != "" ]; then
  zh=1
  export LANG="zh_CN.UTF-8"
else
  zh=0
fi

## Other
try=1
os=$(uname -a)
arch=$(uname -m)
skipNodeInstall=0
skipMCSMInstall=0
oldSystem=0

### Tools ###
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
    echo '================================================='
    [ "${zh}" == 1 ] && printf '\033[1;31;40m%b\033[0m\n' "$2"
    [ "${zh}" == 0 ] && printf '\033[1;31;40m%b\033[0m\n' "$3"
    echo '================================================='
    Clean
    exit 1
    ;;

  # No color echo
  *)
    [ "${zh}" == 1 ] && echo "$2"
    [ "${zh}" == 0 ] && echo "$3"
    ;;
  esac
  return
}

### Entry Point ###
## Program entry point
Main() {
  LEcho cyan "[-] 正在检查环境..." "[-] Initializing environment..."

  # Check mode
  if [ "$1" == "uninstall" ]; then
    mode="uninstall"
  fi

  # Create temp dir
  [ ! -d "${tmpPath}" ] && mkdir -p "${tmpPath}" || rm -rf "${tmpPath}" && mkdir -p "${tmpPath}"
  if [ ! -d "${tmpPath}" ]; then
    CheckRoot
    LEcho error "[x] 未能成功创建临时目录, 请检查权限" "[x] Failed to create temporary directory, please check permissions"
  fi

  # Check functions collection
  if [ "${mode}" == "install" ]; then
    # Install
    CheckSystem
    CheckOldFiles "$1"
    CheckNetwork
    CheckCN
    SetArgs "$1" "$2"

    LEcho cyan "[-] 环境检查完毕, 开始安装 MCSManager" "[-] Environment check completed, start installing MCSManager"

    Install

    if [ -d "${tmpPath}"/mcsmanager ] || [ -d "${tmpPath}"/node ]; then
      LEcho cyan "[-] 检测到备份文件, 正在恢复中..." "[-] Backup files detected, recovering..."
      MirgrateFiles
    fi
  else
    # Uninstall
    CheckRoot
    CheckInstall

    LEcho cyan "[-] 环境校验完毕, 开始卸载 MCSManager" "[-] Environment check completed, start uninstalling MCSManager"

    Remove "$1"
  fi

  return
}

### Init ###
## Check if mcsm installed
CheckInstall() {
  if [ ! -d ${mcsmPath} ]; then
    LEcho error "[x] 检测到您没有安装 MCSManager, 谨慎的拒绝卸载请求" "[x] It is detected that you have not installed MCSManager, and the uninstall request is rejected"
  fi
  return
}

## Check OS
CheckOS() {
  if [ "$(echo "${os}" | grep "Ubuntu")" == "" ] && [ "$(echo "${os}" | grep "Debian")" == "" ] && [ "$(echo "${os}" | grep "CentOS")" == "" ]; then
    LEcho error "[x] 本脚本仅支持 Ubuntu/Debian/CentOS 系统!" "[x] This script only supports Ubuntu/Debian/CentOS systems!"
  fi
  if [ "$(cat /etc/redhat-release | grep ' 6.' | grep -iE 'centos|Red Hat')" ]; then
    LEcho yellow "[!] 检测到您的系统版本过低, 可能会存在一定的兼容性问题, 请了解" "[!] It is detected that your system version is too low, there may be certain compatibility issues, please understand"
    LEcho cyan "[-] 切换为兼容性模式" "[-] Switch to compatibility mode"
    oldSystem=1
  fi
  if [ "$(cat /etc/issue | grep Ubuntu | awk '{print $2}' | cut -f 1 -d '.')" ] && [ "$(cat /etc/issue | grep Ubuntu | awk '{print $2}' | cut -f 1 -d '.')" -lt "16" ]; then
    LEcho yellow "[!] 检测到您的系统版本过低, 可能会存在一定的兼容性问题, 请了解" "[!] It is detected that your system version is too low, there may be certain compatibility issues, please understand"
    LEcho cyan "[-] 切换为兼容性模式" "[-] Switch to compatibility mode"
    oldSystem=1
  fi
  return
}

## Check user permission
CheckRoot() {
  if [ "$(whoami)" != "root" ]; then
    LEcho error "[x] 请使用 root 用户或者使用 sudo 命令执行脚本!" "[x] Please use root user or use sudo command to execute the script!"
  fi
  return
}

## Check system environment
CheckSystem() {
  # Function reuse
  CheckRoot
  CheckOS

  # Check Tools
  if [ -f /etc/redhat-release ]; then
    yum install -y git tar wget curl || LEcho error "[x] 未能成功安装必备软件包" "[x] Failed to install required software packages"
  else
    if [ ${oldSystem} == 1 ]; then
      apt-get install --force-yes git tar wget curl || LEcho error "[x] 未能成功安装必备软件包" "[x] Failed to install required software packages"
    else
      apt-get install -y git tar wget curl || LEcho error "[x] 未能成功安装必备软件包" "[x] Failed to install required software packages"
    fi
  fi

  # Check Arch
  case "${arch}" in
  x86_64)
    arch=x64
    ;;
  aarch64)
    arch=arm64
    ;;
  arm)
    arch=armv7l
    ;;
  ppc64le)
    arch=ppc64le
    ;;
  s390x)
    arch=s390x
    ;;
  *)
    LEcho error "[x] 当前系统架构暂不受 Node.js 支持, 无法安装 MCSManager" "[x] The current system architecture is not supported by Node.js, MCSManager cannot be installed"
    ;;
  esac

  LEcho green "[√] 系统环境检查完成" "[√] System environment check completed"
  return
}

## Check if MCSManager is already installed on system
CheckOldFiles() {
  # Check old MCSManager files
  if [ -d ${mcsmPath} ]; then
    LEcho echo "[-] 检测到旧版本 MCSManager, 正在迁移文件中" "[-] Old version MCSManager detected, migrating files"
    # Create backup dir
    [ ! -d ${tmpPath}/mcsmanager ] && mkdir -p ${tmpPath}/mcsmanager
    [ ! -d ${tmpPath}/systemd ] && mkdir -p ${tmpPath}/systemd

    # Stop service
    systemctl stop mcsm-daemson.service
    systemctl stop mcsm-web.service
    systemctl disable mcsm-daemon.service
    systemctl disable mcsm-web.service

    # Move files
    mv -f ${mcsmPath}/web ${tmpPath}/mcsmanager/web
    mv -f ${mcsmPath}/daemon ${tmpPath}/mcsmanager/daemon
    mv -f /etc/systemd/system/mcsm-daemon.service "${tmpPath}"/systemd/mcsm-daemon.service
    mv -f /etc/systemd/system/mcsm-web.service "${tmpPath}"/systemd/mcsm-web.service
  fi

  # Check old node files
  if [ -d ${nodePath} ]; then
    LEcho echo "[-] 检测到旧版本 Node.js, 正在比对版本中" "[-] Old version Node.js detected, comparing versions"

    # Check node version
    if [ "$(${node} -v)" == "${nodeVersion}" ]; then
      LEcho echo "[-] Node.js 版本匹配, 跳过 Node.js 下载" "[-] Node.js version matches, skipping Node.js download"
      mv -f ${nodePath} ${tmpPath}/node
      skipNodeInstall=1
    fi
  fi

  # Remove old files
  Remove "$1"

  # Create new dir
  mkdir -p ${mcsmPath}

  LEcho green "[√] 旧文件检查完毕" "[√] Old file check completed"
  return
}

# Check network
CheckNetwork() {
  if [ "$(curl -m 10 -s https://www.baidu.com)" == "" ]; then
    LEcho error "[x] 未能成功连接到网络, 请检查网络连接后重试" "[x] Failed to connect to the network, please check the network connection and try again"
  fi
  LEcho green "[√] 网络连接正常" "[√] Network connection is normal"
  return
}

# Check if the server is in China
CheckCN() {
  if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
    # LEcho yellow "[!] 根据 'ipapi.co' 提供的信息, 当前服务器可能在中国" "[!] According to the information provided by 'ipapi.co', the current server IP may be in China"
    # [ "${zh}" == 1 ] && read -e -r -p "[?] 是否选用中国镜像完成安装? [y/n] " input
    # [ "${zh}" == 0 ] && read -e -r -p "[?] Whether to use the Chinese mirror to complete the installation? [y/n] " input
    # case ${input} in
    # [yY][eE][sS] | [yY])
    #   LEcho cyan "[-] 选用中国镜像" "[-] Use Chinese mirror"
    #   daemonCloneURL="https://gitee.com/mcsmanager/MCSManager-Daemon-Production.git"
    #   webCloneURL="https://gitee.com/mcsmanager/MCSManager-Web-Production.git"
    #   nodeMirror="https://npmmirror.com/mirrors/node"
    #   ;;
    # *)
    #   LEcho cyan "[-] 不选用中国镜像" "[-] Do not use Chinese mirror"
    #   ;;
    # esac
    LEcho yellow "[!] 根据 'ipapi.co' 提供的信息, 当前服务器可能在中国, 已自动切换为中国镜像源" "[!] According to the information provided by 'ipapi.co', the current server IP may be in China, and the Chinese mirror source has been automatically switched"
    daemonCloneURL="https://gitee.com/mcsmanager/MCSManager-Daemon-Production.git"
    webCloneURL="https://gitee.com/mcsmanager/MCSManager-Web-Production.git"
    nodeMirror="https://npmmirror.com/mirrors/node"
  else
    LEcho cyan "[-] 检测服务器地理位置出错, 跳过检测" "[-] Error detecting server location, skipping detection"
  fi
  LEcho green "[√] 服务器地理位置检查完毕" "[√] Location check completed"
  return
}

# Set Debug Args
SetArgs() {
  # Warning
  LEcho yellow "[!] 检测到您已启用 debug 功能, 安装可能会导致不可预知的错误" "[!] Debug mode is enabled, installation may cause unpredictable errors"
  LEcho yellow "[!] 此模式导致的任何问题都不会得到解决" "[!] Any problems caused by this mode will not be solved"

  # Set args
  if [ "$1" != "" ] && [ "$1" != "remove" ]; then
    if [ "$1" == "force" ]; then
      LEcho echo "[-] 强制下载 Node.js" "[-] Force download Node.js"
      skipNodeInstall=0
    fi
    if [ "$1" == "skipnode" ]; then
      LEcho echo "[-] 已跳过 Node.js 安装" "[-] Skipped Node.js installation"
      skipNodeInstall=1
    fi
    if [ "$1" == "skipmcsm" ]; then
      LEcho echo "[-] 已跳过 MCSManager 安装" "[-] Skipped MCSManager installation"
      skipMCSMInstall=1
    fi
    if [ "$1" == "custom" ] && [ "$2" != "" ]; then
      LEcho echo "[-] 自定义安装路径为: $2" "[-] Custom installation path: $2"
      mcsmPath="$2"
    fi
    if [ "$1" == "node" ] && [ "$2" != "" ]; then
      LEcho echo "[-] 自定义 Node.js 下载链接为: $2" "[-] Custom Node.js download link: $2"
      nodeMirror="$2"
    fi
  fi
}

### Main ###
## Main install function
Install() {
  InstallNode
  [ ${skipMCSMInstall} != 1 ] && InstallMCSM
}

## Install Node.js
InstallNode() {
  if [ ${skipNodeInstall} == 1 ]; then
    if [ ! -d ${tmpPath}/node ]; then
      LEcho echo "[-] 跳过 Node.js 安装" "[-] Skipped Node.js installation"
    else
      mv -f ${tmpPath}/node ${nodePath}
    fi
  else
    LEcho echo "[+] 正在安装 Node.js" "[+] Installing Node.js"

    # Download Node.js
    wget -t=${try} -q --no-check-certificate --show-progress -O ${tmpPath}/node.tar.gz "${nodeFileURL}"
    wget -t=${try} -q --no-check-certificate --show-progress -O ${tmpPath}/node.sha256 "${nodeHashURL}"

    # Check hash
    cat ${tmpPath}/node.sha256 | grep "${nodeVersion}/node-${nodeVersion}-linux-${arch}.tar.gz" | tee ${tmpPath}/node.sha256
    cd ${tmpPath} || LEcho red "[x] 校验出错, 无法继续进行下一步, 退回操作中..." "[x] Verification error, unable to continue to the next step, returning to operation..." && Revert
    sha256sum -c ${tmpPath}/node.sha256 || LEcho red "[x] 校验出错, 无法继续进行下一步, 退回操作中..." "[x] Verification error, unable to continue to the next step, returning to operation..." && Revert

    # Extract Node.js
    tar -xzvf ${tmpPath}/node.tar.gz -C ${nodePath} --strip-components=1

    # Set permission
    chmod +x ${node}
    chmod +x ${npm}

    # Check Node.js installation
    if ! ${node} -v; then
      LEcho red "[x] Node.js 安装失败, 无法继续进行下一步, 退回操作中..." "[x] Node.js installation failed, please check the network connection"
      Revert
    fi
    if ! ${npm} -v; then
      LEcho red "[x] Node.js 安装失败, 无法继续进行下一步, 退回操作中..." "[x] Node.js installation failed, please check the network connection"
      Revert
    fi

    # Output Node.js version
    echo
    LEcho cyan "=============== Node 版本 ===============" "=============== Node Version ==============="
    LEcho cyan_n " Node: " " Node: "
    LEcho echo "$("${node}" -v)" "$("${node}" -v)"
    LEcho cyan_n " NPM: " " NPM: "
    LEcho echo "v$("${npm}" -v)" "v$("${npm}" -v)"
    LEcho cyan "=========================================" "=============== Node Version ==============="
    echo

    sleep 3
    LEcho green "[√] Node.js 安装完毕" "[√] Node.js installation completed"
  fi
  return
}

## Install MCSManager
InstallMCSM() {
  # Clone MCSManager daemon and web
  git clone --single-branch -b master --depth 1 ${daemonCloneURL} "${mcsmPath}/daemon"
  git clone --single-branch -b master --depth 1 ${webCloneURL} "${mcsmPath}/web"

  # Install Node.js dependencies
  cd "${mcsmPath}/daemon" || LEcho red "[x] 无法进入 MCSManager 守护进程目录, 无法继续进行下一步, 退回操作中..." "[x] Unable to enter the MCSManager daemon directory, unable to continue to the next step, returning to operation..." && Revert
  ${npm} install --registry=https://registry.npmmirror.com >error
  cd "${mcsmPath}/web" || LEcho red "[x] 无法进入 MCSManager 网页面板目录, 无法继续进行下一步, 退回操作中..." "[x] Unable to enter the MCSManager web directory, unable to continue to the next step, returning to operation..." && Revert
  ${npm} install --registry=https://registry.npmmirror.com >error

  # Output MCSManager install path
  echo
  LEcho cyan "=============== MCSManager 安装目录 ===============" "=============== MCSManager Install Path ==============="
  LEcho cyan_n " Daemon: " " Daemon: "
  LEcho echo "${mcsmPath}/daemon" "${mcsmPath}/daemon"
  LEcho cyan_n " Web: " " Web: "
  LEcho echo "${mcsmPath}/web" "${mcsmPath}/web"
  LEcho cyan "==================================================" "=============== MCSManager Install Path ==============="
  echo

  # Function reuse
  CreateService
  MirgrateFiles

  # Test the availability of MCSManager
  if ! systemctl start mcsm-web; then
    LEcho red "[x] MCSManager 网页面板启动失败, 无法继续进行下一步, 退回操作中..." "[x] MCSManager installation failed, unable to continue to the next step, returning to operation..." && Revert
  else
    systemctl stop mcsm-web
  fi
  if ! systemctl start mcsm-daemon; then
    LEcho red "[x] MCSManager 守护进程启动失败, 无法继续进行下一步, 退回操作中..." "[x] MCSManager installation failed, unable to continue to the next step, returning to operation..." && Revert
  else
    systemctl stop mcsm-daemon
  fi

  LEcho green "[√] MCSManager 安装完毕" "[√] MCSManager installation completed"

  sleep 3
  Output
  return
}

## Create systemd service
CreateService() {
  # Write systemd service
  echo "
[Unit]
Description=MCSManager Daemon

[Service]
WorkingDirectory=/opt/mcsmanager/daemon
ExecStart=${nodePath}/bin/node app.js
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
ExecStart=${nodePath}/bin/node app.js
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
Environment=\"PATH=${PATH}\"

[Install]
WantedBy=multi-user.target
" >/etc/systemd/system/mcsm-web.service

  # Enable systemd service
  systemctl daemon-reload
  systemctl enable mcsm-daemon.service --now
  systemctl enable mcsm-web.service --now

  sleep 3
  return
}

## Mirgrate data
MirgrateFiles() {
  # Mirgrate mcsmanager data
  if [ -d "${tmpPath}"/mcsmanager ]; then
    [ ! -d "${mcsmWebDPath}" ] && mv -f "${tmpPath}"/mcsmanager/web/data "${mcsmWebDPath}" || rm -rf ${mcsmWebDPath} && mv -f "${tmpPath}"/mcsmanager/web/data "${mcsmWebDPath}"
    [ ! -d "${mcsmWebDPath}" ] && mv -f "${tmpPath}"/mcsmanager/daemon/data "${mcsmDaemonDPath}" || rm -rf ${mcsmDaemonDPath} && mv -f "${tmpPath}"/mcsmanager/daemon/data "${mcsmDaemonDPath}"
  fi

  # Mirgrate old node files
  if [ -d "${tmpPath}"/node ]; then
    mv -f "${tmpPath}"/node "${nodePath}"
  fi
}

## Output MCSManager information
Output() {
  printf "\033c"
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
}

## Main remove function
Remove() {
  # Stop systemd service
  if [ "$1" != "remove" ]; then
    systemctl stop mcsm-daemson.service
    systemctl stop mcsm-web.service
    systemctl disable mcsm-daemon.service
    systemctl disable mcsm-web.service
  fi

  # Remove systemd service
  [ -f /etc/systemd/system/mcsm-daemon.service ] && rm -rf /etc/systemd/system/mcsm-daemon.service
  [ -f /etc/systemd/system/mcsm-daemon.service ] && rm -rf /etc/systemd/system/mcsm-web.service
  systemctl daemon-reload

  # Ask if data is retained
  if [ -d "${mcsmDaemonDPath}" ] || [ -d "${mcsmWebDPath}" ]; then
    LEcho yellow "[?] 是否保留数据？" "[?] Do you want to keep the data?"
    read -r -p "[y/N]:" input
    case ${input} in
    [yY][eE][sS] | [yY])
      LEcho echo "[-] 保留数据" "[-] Keep data"
      mv -f "${mcsmDaemonDPath}" "${tmpPath}"/mcsmanager/daemon
      mv -f "${mcsmWebDPath}" "${tmpPath}"/mcsmanager/web
      rm -rf "${mcsmPath}"
      mv -f "${tmpPath}"/mcsmanager "${mcsmPath}.old"
      ;;
    *)
      LEcho echo "[-] 删除数据" "[-] Delete data"
      rm -rf "${mcsmPath}"
      ;;
    esac
  fi
  return
}

### Other Functions ###
## Revert Script Operation
Revert() {
  # Remove new files
  rm -rf "${mcsmPath}"
  rm -rf "${nodePath}"
  rm -rf /etc/systemd/system/mcsm-daemon.service
  rm -rf /etc/systemd/system/mcsm-web.service

  # Restore old files
  mv -f "${tmpPath}"/mcsmanager "${mcsmPath}"
  mv -f "${tmpPath}"/node "${nodePath}"
  mv -f "${tmpPath}"/systemd/mcsm-daemon.service /etc/systemd/system/mcsm-daemon.service
  mv -f "${tmpPath}"/systemd/mcsm-web.service /etc/systemd/system/mcsm-web.service

  # Re-enable systemd service
  systemctl daemon-reload
  systemctl enable mcsm-daemon.service
  systemctl enable mcsm-web.service

  LEcho error "[x] 安装失败" "[x] Installation failed"
}

## Clean Function
Clean() {
  rm -rf "${tmpPath}"
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
Main "$1" "$2" "$3"
Clean
exit 0
