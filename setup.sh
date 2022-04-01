#!/bin/bash
printf "\033c"

arch=$(uname -m)
mcsmanager_install_path="/opt/mcsmanager"


Red_Error() {
  echo '================================================='
  printf '\033[1;31;40m%b\033[0m\n' "$@"
  echo '================================================='
  exit 1
}
 
Install_Node() {
  node_install_path="/opt/node-v14.19.1-linux-${arch}"

  echo "[x] rm -irf ${node_install_path}"
  rm -irf ${node_install_path}

  echo "[→] cd /opt || exit"
  cd /opt || exit

  echo "[↓] wget https://npm.taobao.org/mirrors/node/v14.19.1/node-v14.19.1-linux-${arch}.tar.gz"
  wget https://npm.taobao.org/mirrors/node/v14.19.1/node-v14.19.1-linux-${arch}.tar.gz

  echo "[↑] tar -zxf node-v14.19.1-linux-${arch}.tar.gz"
  tar -zxf node-v14.19.1-linux-${arch}.tar.gz

  echo "[x] rm -rf node-v14.19.1-linux-${arch}.tar.gz"
  rm -rf node-v14.19.1-linux-${arch}.tar.gz

  #echo "[x] Delete the original Node link"
  #rm -f /usr/bin/npm
  #rm -f /usr/bin/node
  #rm -f /usr/local/bin/npm
  #rm -f /usr/local/bin/node

  #echo "[+] Creating a Node link"
  #ln -s ${node_install_path}/bin/npm /usr/bin/
  #ln -s ${node_install_path}/bin/node /usr/bin/
  #ln -s ${node_install_path}/bin/npm /usr/local/bin/
  #ln -s ${node_install_path}/bin/node /usr/local/bin/
  
  echo "=============== Node Version ==============="
  echo " node: $(${node_install_path}/bin/node -v)"
  #echo " npm: $(${node_install_path}/bin/npm -v)"
  echo "=============== Node Version ==============="
  echo
  echo "[-] Node Installed Successfully!"
  echo

  sleep 3
}

Install_MCSManager() {
  echo "[x] Delete the original MCSManager"
  rm -irf ${mcsmanager_install_path}

  echo "[+] mkdir -p ${mcsmanager_install_path}"
  mkdir -p ${mcsmanager_install_path} || exit

  echo "[→] cd ${mcsmanager_install_path}"
  cd ${mcsmanager_install_path} || exit

  echo "[↓] git clone https://gitee.com/mcsmanager/MCSManager-Daemon-Production.git"
  git clone https://gitee.com/mcsmanager/MCSManager-Daemon-Production.git

  echo "[-] mv MCSManager-Daemon-Production daemon"
  mv MCSManager-Daemon-Production daemon

  echo "[→] cd daemon"
  cd daemon || exit

  echo "[+] npm install --registry=https://registry.npm.taobao.org"
  env ${node_install_path}/bin/node ${node_install_path}/bin/npm install --registry=https://registry.npm.taobao.org

  echo "[←] cd .."
  cd ..

  echo "[↓] git clone https://gitee.com/mcsmanager/MCSManager-Web-Production.git"
  git clone https://gitee.com/mcsmanager/MCSManager-Web-Production.git

  echo "[-] mv MCSManager-Web-Production web"
  mv MCSManager-Web-Production web

  echo "[→] cd web"
  cd web || exit

  echo "[+] npm install --registry=https://registry.npm.taobao.org"
  env ${node_install_path}/bin/node ${node_install_path}/bin/npm install --registry=https://registry.npm.taobao.org

  echo "=============== MCSManager ==============="
  echo " Daemon: ${mcsmanager_install_path}/daemon"
  echo " Web: ${mcsmanager_install_path}/web"
  echo "=============== MCSManager ==============="
  echo
  echo ""
  echo -e "\033[1;32m[ok] MCSManager installed successfully!!!\033[0m"
  echo "[ok] Location: ${mcsmanager_install_path}"
  echo
  sleep 3
}

Create_Service() {

  echo "[x] Initialize the service file"
  rm -f /etc/systemd/system/mcsm-daemon.service
  rm -f /etc/systemd/system/mcsm-web.service

  echo "[+] creating >>/etc/systemd/system/mcsm-daemon.service"
  echo "
[Unit]
Description=MCSManager Daemon

[Service]
WorkingDirectory=/opt/mcsmanager/daemon
ExecStart=${node_install_path}/bin/node app.js
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/mcsm-daemon.service

  echo "[+] creating >>/etc/systemd/system/mcsm-web.service"
  echo "
[Unit]
Description=MCSManager Web

[Service]
WorkingDirectory=/opt/mcsmanager/web
ExecStart=${node_install_path}/bin/node app.js
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/mcsm-web.service

  echo "[-] systemctl daemon-reload"
  systemctl daemon-reload

  echo "[+] systemctl enable mcsm-daemon.service --now"
  systemctl enable mcsm-daemon.service --now

  echo "[+] systemctl enable mcsm-web.service --now"
  systemctl enable mcsm-web.service --now

  sleep 4

  echo "=================================================================="
  echo -e "\033[1;32mWelcome to MCSManager\033[0m"
  echo "=================================================================="
  echo "Web Service Address:    http://localhost:23333"
  echo "Daemon Service Address: http://localhost:24444"
  echo "Username: root"
  echo "Password: 123456"
  echo -e "\033[33mYou must expose ports 23333 and 24444 to use the service properly on the Internet.\033[0m"
  echo "=================================================================="
  echo "systemctl restart mcsm-{daemon,web}.service"
  echo "systemctl disable mcsm-{daemon,web}.service"
  echo "systemctl enable mcsm-{daemon,web}.service"
  echo "systemctl start mcsm-{daemon,web}.service"
  echo "systemctl stop mcsm-{daemon,web}.service"
  echo "=================================================================="

}

# ----------------- Program start ----------------- 

# rm -f "$0"

if [ $(whoami) != "root" ]; then
  Red_Error "[x] Please use Root!"
fi

# Config Architecture
if [[ $arch == x86_64 ]] || [[ $arch == aarch64 ]] || [[ $arch == ppc64le ]] || [[ $arch == s390x ]] || [[ $arch == arm ]]; then
if [ $arch == x86_64 ]; then
  arch=x64
  echo "x64 architecture detected"
fi
if [ $arch == aarch64 ]; then
  arch=arm64
    echo "64-bit ARM architecture detected"
fi
if [ $arch == arm ]; then
  arch=armv7l
    echo "32-bit ARM architecture detected"
fi
if [ $arch == ppc64le ]; then
  echo "IBM POWER architecture detected"
fi
if [ $arch == s390x ]; then
  echo "IBM LinuxONE architecture detected"
fi
else
  Red_Error "[x] Sorry, this architecture is not supported yet!"
fi

# Check 64-bit
#is64bit=$(getconf LONG_BIT)
#if [ "${is64bit}" != '64' ]; then
#  Red_Error "[x] Please use 64-bit system!"  
#fi


echo "+----------------------------------------------------------------------
| MCSManager Installer
+----------------------------------------------------------------------
| Copyright © 2022 Suwings All rights reserved.
+----------------------------------------------------------------------
| Shell Install Script by Nuomiaa
+----------------------------------------------------------------------
"

echo "[+] Installing dependent software... (git,tar)"
yum install -y git tar
apt install -y git tar
pacman -Syu --noconfirm git tar

Install_Node
Install_MCSManager
Create_Service
