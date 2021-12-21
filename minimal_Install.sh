#!/bin/bash
printf "\033c"

mcsmanager_install_path="/opt/mcsmanager"
node_install_path="/opt/node-v14.17.6-linux-x64"

Red_Error() {
  echo '================================================='
  printf '\033[1;31;40m%b\033[0m\n' "$@"
  exit 1
}

Install_Node() {

  echo "[x] Delete the original Node environment"
  rm -irf ${node_install_path}

  echo "[→] 进入 Node 安装目录"
  cd /opt || exit

  echo "[↓] 下载 Node v14.17.6 压缩包..."
  wget https://npm.taobao.org/mirrors/node/v14.17.6/node-v14.17.6-linux-x64.tar.gz

  echo "[↑] 解压 node-v14.17.6-linux-x64.tar.gz"
  tar -zxf node-v14.17.6-linux-x64.tar.gz

  echo "[x] 删除 node-v14.17.6-linux-x64.tar.gz"
  rm -rf node-v14.17.6-linux-x64.tar.gz

  echo "[x] 删除原有 Node 链接"
  rm -f /usr/bin/npm
  rm -f /usr/bin/node
  rm -f /usr/local/bin/npm
  rm -f /usr/local/bin/node

  echo "[+] 创建 Node 链接"
  ln -s ${node_install_path}/bin/npm /usr/bin/
  ln -s ${node_install_path}/bin/node /usr/bin/
  ln -s ${node_install_path}/bin/npm /usr/local/bin/
  ln -s ${node_install_path}/bin/node /usr/local/bin/

  printf "\033c"
  echo "=============== Node Version ==============="
  echo " node: $(node -v)"
  echo " npm: $(npm -v)"
  echo "=============== Node Version ==============="
  echo
  echo "[-] Node 安装完成，即将开始安装 MCSManager..."
  echo
  sleep 3
}

Install_MCSManager() {
  printf "\033c"

  echo "[x] 删除原有 MCSManager"
  rm -irf ${mcsmanager_install_path}

  echo "[+] 创建 MCSManager 安装目录"
  mkdir -p ${mcsmanager_install_path} || exit

  echo "[→] 进入 MCSManager 安装目录"
  cd ${mcsmanager_install_path} || exit

  echo "[↓] 下载 MCSManager 守护进程..."
  git clone https://github.com.cnpmjs.org/nuomiaa/Daemon.git

  echo "[-] 重命名 Daemon -> daemon"
  mv Daemon daemon

  echo "[→] 进入 MCSManager-Daemon 目录"
  cd daemon || exit

  echo "[+] 安装 npm 依赖库..."
  npm install --registry=https://registry.npm.taobao.org

  echo "[←] 退出 MCSManager-Daemon 目录"
  cd ..

  echo "[↓] 下载 MCSManager-Web 网页服务..."
  git clone https://github.com.cnpmjs.org/nuomiaa/Web.git

  echo "[-] 重命名 Web -> web"
  mv Web web

  echo "[→] 进入 MCSManager-Web 目录"
  cd web || exit

  echo "[+] 安装 npm 依赖库..."
  npm install --registry=https://registry.npm.taobao.org

  printf "\033c"
  echo "=============== MCSManager ==============="
  echo " Daemon(守护进程): ${mcsmanager_install_path}/daemon"
  echo " Web(网页服务): ${mcsmanager_install_path}/web"
  echo "=============== MCSManager ==============="
  echo
  echo "[-] MCSManager 安装完成，即将开始创建 MCSManager 系统服务..."
  echo
  sleep 3
}

Create_Service() {
  printf "\033c"

  echo "[x] 删除 MCSManager 服务"
  rm -f /etc/systemd/system/mcsm-daemon.service
  rm -f /etc/systemd/system/mcsm-web.service

  echo "[+] 创建 MCSManager-Daemon 服务"
  cat >>/etc/systemd/system/mcsm-daemon.service <<'EOF'
[Unit]
Description=MCSManager Daemon

[Service]
WorkingDirectory=/opt/mcsmanager/daemon
ExecStart=/usr/bin/node app.js
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID

[Install]
WantedBy=multi-user.target
EOF

  echo "[+] 创建 MCSManager-Web 服务"
  cat >>/etc/systemd/system/mcsm-web.service <<'EOF'
[Unit]
Description=MCSManager Web

[Service]
WorkingDirectory=/opt/mcsmanager/web
ExecStart=/usr/bin/node app.js
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID

[Install]
WantedBy=multi-user.target
EOF

  echo "[-] 重载服务配置文件"
  systemctl daemon-reload

  echo "[+] 启用 MCSManager-Daemon 服务"
  systemctl enable mcsm-daemon.service --now

  echo "[+] 启用 MCSManager-Web 服务"
  systemctl enable mcsm-web.service --now

  echo "[↓] 下载 MCSManager-命令行..."
  rm -f /opt/mcsm.sh
  wget -P /opt https://shell.ea0.cn/mcsm.sh
  chmod -R 755 /opt/mcsm.sh

  echo "[+] 创建 MCSManager-命令行 链接"
  rm -f /usr/local/bin/mcsm
  ln -s /opt/mcsm.sh /usr/local/bin/mcsm

  echo "[-] 正在检查服务..."

  sleep 5

  printf "\033c"
  if (systemctl -q is-active mcsm-daemon.service && systemctl -q is-active mcsm-web.service); then
    getIpAddress=$(curl -sS --connect-timeout 10 -m 60 https://shell.ea0.cn/api/getIpAddress)
    LOCAL_IP=$(ip addr | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -E -v "^127\.|^255\.|^0\." | head -n 1)

    echo "=================================================================="
    echo -e "\033[1;32mMCSManager - 恭喜，安装成功！\033[0m"
    echo "=================================================================="
    echo "网页服务地址-内网: http://${LOCAL_IP}:23333"
    echo "守护进程地址-内网: http://${LOCAL_IP}:24444"
    echo "网页服务地址: http://${getIpAddress}:23333"
    echo "守护进程地址: http://${getIpAddress}:24444"
    echo "默认账号: root"
    echo "默认密码: 123456"
    echo -e "\033[33m若无法访问面板，请检查防火墙/安全组是否有放行面板[23333/24444]端口\033[0m"
    #echo "=================================================================="
    #echo "重启服务: systemctl restart mcsm-{daemon,web}.service"
    #echo "禁用服务: systemctl disable mcsm-{daemon,web}.service"
    #echo "启用服务: systemctl enable mcsm-{daemon,web}.service"
    #echo "启动服务: systemctl start mcsm-{daemon,web}.service"
    #echo "停止服务: systemctl stop mcsm-{daemon,web}.service"
    echo "=================================================================="
    echo "您可以在命令行使用 \"mcsm\" 呼出 MCSManager-命令行"
  else
    Red_Error "[x] 服务启动失败"
  fi
}




echo "+----------------------------------------------------------------------
| MCSManager FOR CentOS/Ubuntu/Debian
+----------------------------------------------------------------------
| Copyright © 2017-2021 Suwings(MCSManager.com) All rights reserved.
+----------------------------------------------------------------------
| Shell Install Script by Nuomiaa & Suwings
+----------------------------------------------------------------------
"

if [ $(whoami) != "root" ]; then
  Red_Error "[x] Please use the root!"
fi


echo "[+] Installing dependent software..."
yum install -y git tar
apt install -y git tar
pacman -Syu --noconfirm git tar


echo "[+] Start installation..."
Install_Node
Install_MCSManager
Create_Service