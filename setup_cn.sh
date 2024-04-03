#!/bin/bash

mcsmanager_install_path="/opt/mcsmanager"
mcsmanager_donwload_addr="http://oss.duzuii.com/d/MCSManager/MCSManager/MCSManager-v10-linux.tar.gz"
package_name="MCSManager-v10-linux.tar.gz"
node="v16.20.2"

error=""
arch=$(uname -m)

printf "\033c"

echo_cyan() {
  printf '\033[1;36m%b\033[0m\n' "$@"
}
echo_red() {
  printf '\033[1;31m%b\033[0m\n' "$@"
}

echo_green() {
  printf '\033[1;32m%b\033[0m\n' "$@"
}

echo_cyan_n() {
  printf '\033[1;36m%b\033[0m' "$@"
}

echo_yellow() {
  printf '\033[1;33m%b\033[0m\n' "$@"
}

echo_cyan "+----------------------------------------------------------------------
| MCSManager 安装脚本
+----------------------------------------------------------------------

MCSManager 安装脚本不会破坏您系统上原有的任何服务以及环境变量，安装脚本所有的一切均为无污染的安全行为！
我们只会在 /opt 目录下创建两个文件夹，一个用于存放 NodeJS 运行时，一个用于存放 MCSManager 代码文件，并且尝试添加 MCSM 到系统服务！
"

Red_Error() {
  echo '================================================='
  printf '\033[1;31;40m%b\033[0m\n' "$@"
  echo '================================================='
  exit 1
}

Install_Node() {
  echo_cyan_n "[+] 正在安装 NodeJS 运行时环境...\n"

  sudo rm -irf "$node_install_path"

  cd /opt || exit

  rm -rf node-"$node"-linux-"$arch".tar.gz

  wget https://nodejs.org/dist/"$node"/node-"$node"-linux-"$arch".tar.gz

  tar -zxf node-"$node"-linux-"$arch".tar.gz

  rm -rf node-"$node"-linux-"$arch".tar.gz

  if [[ -f "$node_install_path"/bin/node ]] && [[ "$("$node_install_path"/bin/node -v)" == "$node" ]]; then
    echo_green "Success"
  else
    echo_red "Failed"
    Red_Error "[x] Node installation failed!"
  fi

  echo
  echo_yellow "=============== Node.JS Version ==============="
  echo_yellow " node: $("$node_install_path"/bin/node -v)"
  echo_yellow " npm: v$(/usr/bin/env "$node_install_path"/bin/node "$node_install_path"/bin/npm -v)"
  echo_yellow "=============== Node.JS Version ==============="
  echo

  sleep 3
}

Install_MCSManager() {
  echo_cyan "[+] 正在安装面板..."

  # stop service
  sudo systemctl stop mcsm-{web,daemon}
  sudo systemctl disable mcsm-{web,daemon}

  # delete service
  sudo rm -rf /etc/systemd/system/mcsm-daemon.service
  sudo rm -rf /etc/systemd/system/mcsm-web.service
  sudo systemctl daemon-reload

  mkdir -p ${mcsmanager_install_path} || exit

  # cd /opt/mcsmanager
  cd ${mcsmanager_install_path} || exit

  # donwload MCSManager release
  wget ${mcsmanager_donwload_addr}
  tar -zxf ${package_name} -o || exit
  rm -rf "${mcsmanager_install_path}/${package_name}"

  # echo "[→] cd daemon"
  cd daemon || exit

  echo_cyan "[+] Install MCSManager-Daemon dependencies..."
  /usr/bin/env "$node_install_path"/bin/node "$node_install_path"/bin/npm install --production --no-fund --no-audit >npm_install_log

  # echo "[←] cd .."
  cd ../web || exit

  echo_cyan "[+] Install MCSManager-Web dependencies..."
  /usr/bin/env "$node_install_path"/bin/node "$node_install_path"/bin/npm install --production --no-fund --no-audit >npm_install_log

  echo
  echo_yellow "=============== MCSManager ==============="
  echo_green " Daemon: ${mcsmanager_install_path}/daemon"
  echo_green " Web: ${mcsmanager_install_path}/web"
  echo_yellow "=============== MCSManager ==============="
  echo
  echo_green "[+] MCSManager installation success!"

  sudo chmod -R 755 /opt/mcsmanager/

  sleep 3
}

Create_Service() {
  echo_cyan "[+] 注册系统服务中..."
  echo_cyan "[!] Try to register to the "systemctl", This comomand require \"root\" permission."

  sudo echo "[Unit]
Description=MCSManager-Daemon

[Service]
WorkingDirectory=/opt/mcsmanager/daemon
ExecStart=${node_install_path}/bin/node app.js
ExecReload=/bin/kill -s QUIT $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
Environment=\"PATH=${PATH}\"

[Install]
WantedBy=multi-user.target
" >/etc/systemd/system/mcsm-daemon.service

  sudo echo "[Unit]
Description=MCSManager-Web

[Service]
WorkingDirectory=/opt/mcsmanager/web
ExecStart=${node_install_path}/bin/node app.js
ExecReload=/bin/kill -s QUIT $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
Environment=\"PATH=${PATH}\"

[Install]
WantedBy=multi-user.target
" >/etc/systemd/system/mcsm-web.service

  if [ -e "/etc/systemd/system/mcsm-web.service" ]; then
    sudo systemctl daemon-reload
    sudo systemctl enable mcsm-daemon.service --now
    sudo systemctl enable mcsm-web.service --now
    echo_green "Registered!"
  else
    printf "\n\n"
    echo_red "面板已成功安装到目录： \"/opt/mcsmanager\"."
    echo_red "但是由于权限不足，无法注册到系统服务中，你可以手动启动面板（参考 Github Readme.md）或重新使用 root 权限安装！"
    exit
  fi

  sleep 2

  printf "\n\n\n\n"

  echo_yellow "=================================================================="
  echo_green "MCSManager 面板已安装完成！接下来您只需在浏览器访问即可愉快的使用它！"
  echo_yellow " "
  echo_cyan_n "请使用浏览器访问此地址:        "
  echo_yellow "http://<公网IP>:23333"
  echo_cyan_n "守护进程地址（集群用）:          "
  echo_yellow "ws://<公网IP>:24444"
  echo_red "注意：您必须开放 23333 和 24444 两个端口才能保证服务正常访问！"
  echo_yellow " "
  echo_cyan "面板常用命令:"
  echo_cyan "systemctl start mcsm-{daemon,web}.service   # 开启面板"
  echo_cyan "systemctl stop mcsm-{daemon,web}.service    # 关闭面板"
  echo_cyan "systemctl restart mcsm-{daemon,web}.service # 重启面板"
  echo_yellow " "
  echo_green "官方文档: https://docs.mcsmanager.com/"
  echo_yellow "=================================================================="
}

# Environmental inspection
if [[ "$arch" == x86_64 ]]; then
  arch=x64
  #echo "[-] x64 architecture detected"
elif [[ $arch == aarch64 ]]; then
  arch=arm64
  #echo "[-] 64-bit ARM architecture detected"
elif [[ $arch == arm ]]; then
  arch=armv7l
  #echo "[-] 32-bit ARM architecture detected"
elif [[ $arch == ppc64le ]]; then
  arch=ppc64le
  #echo "[-] IBM POWER architecture detected"
elif [[ $arch == s390x ]]; then
  arch=s390x
  #echo "[-] IBM LinuxONE architecture detected"
else
  Red_Error "[x] Sorry, this architecture is not supported yet!"
  Red_Error "[x] Please try to install manually: https://github.com/MCSManager/MCSManager#linux"
  exit
fi

# Define the variable Node installation directory
node_install_path="/opt/node-$node-linux-$arch"

# Check network connection
echo_cyan "[-] Architecture: $arch"

# Install related software
echo_cyan_n "[+] Installing dependent software(git,tar)... "
if [[ -x "$(command -v yum)" ]]; then
  sudo yum install -y git tar >error
elif [[ -x "$(command -v apt-get)" ]]; then
  sudo apt-get install -y git tar >error
elif [[ -x "$(command -v pacman)" ]]; then
  sudo pacman -Syu --noconfirm git tar >error
elif [[ -x "$(command -v zypper)" ]]; then
  sudo zypper --non-interactive install git tar >error
fi

# Determine whether the relevant software is installed successfully
if [[ -x "$(command -v git)" && -x "$(command -v tar)" ]]; then
  echo_green "Success"
else
  echo_red "Failed"
  echo "$error"
  Red_Error "[x] Related software installation failed, please install git and tar packages manually!"
  exit
fi

# Install the Node environment
Install_Node

# Install MCSManager
Install_MCSManager

# Create MCSManager background service
Create_Service
