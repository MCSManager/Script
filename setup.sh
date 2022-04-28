#!/bin/bash
printf "\033c"

error=""
node="v14.19.1"
arch=$(uname -m)
mcsmanager_install_path="/opt/mcsmanager"
zh=$([[ $(locale -a) =~ "zh" ]] && echo 1; export LANG=zh_CN.UTF-8 || echo 0)

Red_Error() {
  echo '================================================='
  printf '\033[1;31;40m%b\033[0m\n' "$@"
  echo '================================================='
  exit 1
}

echo_red() {
  printf '\033[1;31m%b\033[0m\n' "$@"
}

echo_green() {
  printf '\033[1;32m%b\033[0m\n' "$@"
}

echo_cyan() {
  printf '\033[1;36m%b\033[0m\n' "$@"
}

echo_cyan_n() {
  printf '\033[1;36m%b\033[0m' "$@"
}

echo_yellow() {
  printf '\033[1;33m%b\033[0m\n' "$@"
}

Install_Node() {
  if [ "$zh" == 1 ];
    then echo_cyan_n "[+] 安装 Node 环境... "
    else echo_cyan_n "[+] Install Node environment... "
  fi

  rm -irf "$node_install_path"

  cd /opt || exit

  wget -o /dev/null https://npmmirror.com/mirrors/node/"$node"/node-"$node"-linux-"$arch".tar.gz

  tar -zxf node-"$node"-linux-"$arch".tar.gz

  rm -rf node-"$node"-linux-"$arch".tar.gz

  if [ -f "$node_install_path"/bin/node ] && [ "$("$node_install_path"/bin/node -v)" == "$node" ]
  then
    if [ "$zh" == 1 ];
      then echo_green "成功"
      else echo_green "Success"
    fi
  else
    if [ "$zh" == 1 ];
      then
        echo_red "失败"
        Red_Error "[x] Node 安装失败！"
      else
        echo_red "Failed"
        Red_Error "[x] Node installation failed!"
    fi
  fi

  echo
  echo_yellow "=============== Node Version ==============="
  echo_yellow " node: $("$node_install_path"/bin/node -v)"
  echo_yellow " npm: v$(/usr/bin/env "$node_install_path"/bin/node "$node_install_path"/bin/npm -v)"
  echo_yellow "=============== Node Version ==============="
  echo

  sleep 3
}

Install_MCSManager() {
  if [ "$zh" == 1 ];
    then echo_cyan "[+] 安装 MCSManager..."
    else echo_cyan "[+] Install MCSManager..."
  fi
  
  # echo "[x] Delete the original MCSManager"
  rm -irf ${mcsmanager_install_path}

  # echo "[+] mkdir -p ${mcsmanager_install_path}"
  mkdir -p ${mcsmanager_install_path} || exit

  # echo "[→] cd ${mcsmanager_install_path}"
  cd ${mcsmanager_install_path} || exit

  if [ "$zh" == 1 ];
    then echo_cyan "[↓] Git 克隆 MCSManager-Daemon..."
    else echo_cyan "[↓] Git clone MCSManager-Daemon..."
  fi
  git clone https://gitee.com/mcsmanager/MCSManager-Daemon-Production.git

  # echo "[-] mv MCSManager-Daemon-Production daemon"
  mv MCSManager-Daemon-Production daemon

  # echo "[→] cd daemon"
  cd daemon || exit

  if [ "$zh" == 1 ];
    then echo_cyan "[+] 安装 MCSManager-Daemon 依赖库..."
    else echo_cyan "[+] Install MCSManager-Daemon dependencies..."
  fi
  /usr/bin/env "$node_install_path"/bin/node "$node_install_path"/bin/npm install --registry=https://registry.npmmirror.com > error

  # echo "[←] cd .."
  cd ..

  if [ "$zh" == 1 ];
    then echo_cyan "[↓] Git 克隆 MCSManager-Web..."
    else echo_cyan "[↓] Git clone MCSManager-Web..."
  fi
  git clone https://gitee.com/mcsmanager/MCSManager-Web-Production.git

  # echo "[-] mv MCSManager-Web-Production web"
  mv MCSManager-Web-Production web

  # echo "[→] cd web"
  cd web || exit

  if [ "$zh" == 1 ];
    then echo_cyan "[+] 安装 MCSManager-Web 依赖库..."
    else echo_cyan "[+] Install MCSManager-Web dependencies..."
  fi
  /usr/bin/env "$node_install_path"/bin/node "$node_install_path"/bin/npm install --registry=https://registry.npmmirror.com > error

  echo
  echo_yellow "=============== MCSManager ==============="
  echo_green " Daemon: ${mcsmanager_install_path}/daemon"
  echo_green " Web: ${mcsmanager_install_path}/web"
  echo_yellow "=============== MCSManager ==============="
  echo
  if [ "$zh" == 1 ];
    then echo_green "[+] MCSManager 安装成功！"
    else echo_green "[+] MCSManager installation success!"
  fi

  sleep 3
}

Create_Service() {
  if [ "$zh" == 1 ];
    then echo_cyan "[+] 创建 MCSManager 服务..."
    else echo_cyan "[+] Create MCSManager service..."
  fi

  rm -f /etc/systemd/system/mcsm-daemon.service
  rm -f /etc/systemd/system/mcsm-web.service

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

  # 重载
  systemctl daemon-reload

  # 创建 Daemon 服务
  systemctl enable mcsm-daemon.service --now

  # 创建 Web 服务
  systemctl enable mcsm-web.service --now

  sleep 3

  printf "\033c"
  echo_yellow "=================================================================="
  if [ "$zh" == 1 ];
  then
    echo_green "欢迎使用 MCSManager，您可以通过以下方式访问："
    echo_yellow "=================================================================="
    echo_cyan_n "Daemon 服务地址："; echo_yellow "http://localhost:24444"
    echo_cyan_n "Web 服务地址：   "; echo_yellow "http://localhost:23333"
    echo_cyan_n "账号: "; echo_yellow "root"
    echo_cyan_n "密码: "; echo_yellow "123456"
    echo_red "若无法访问面板，请检查防火墙/安全组是否有放行面板[23333/24444]端口"
    echo_yellow "=================================================================="
    echo_cyan "重启 systemctl restart mcsm-{daemon,web}.service"
    echo_cyan "禁用 systemctl disable mcsm-{daemon,web}.service"
    echo_cyan "启用 systemctl enable mcsm-{daemon,web}.service"
    echo_cyan "启动 systemctl start mcsm-{daemon,web}.service"
    echo_cyan "停止 systemctl stop mcsm-{daemon,web}.service"
  else
    echo_green "Welcome to MCSManager, you can access it by the following ways:"
    echo_yellow "=================================================================="
    echo_cyan_n "Daemon Service Address: "; echo_yellow "http://localhost:24444"
    echo_cyan_n "Web Service Address:    "; echo_yellow "http://localhost:23333"
    echo_cyan_n "Username: "; echo_yellow "root"
    echo_cyan_n "Password: "; echo_yellow "123456"
    echo_red "You must expose ports 23333 and 24444 to use the service properly on the Internet."
    echo_yellow "=================================================================="
    echo_cyan "systemctl restart mcsm-{daemon,web}.service"
    echo_cyan "systemctl disable mcsm-{daemon,web}.service"
    echo_cyan "systemctl enable mcsm-{daemon,web}.service"
    echo_cyan "systemctl start mcsm-{daemon,web}.service"
    echo_cyan "systemctl stop mcsm-{daemon,web}.service"
  fi
  echo_yellow "=================================================================="

  

}


# ----------------- 程序启动 -----------------

# 删除 Shell 脚本自身
rm -f "$0"

# 检查执行用户权限
if [ "$(whoami)" != "root" ]; then
  if [ "$zh" == 1 ];
    then Red_Error "[x] 请使用 root 权限执行 MCSManager 安装命令！"
    else Red_Error "[x] Please execute the MCSManager installation command with root permission!"
  fi
fi

echo_cyan "+----------------------------------------------------------------------
| MCSManager Installer
+----------------------------------------------------------------------
| Copyright © 2022 Suwings All rights reserved.
+----------------------------------------------------------------------
| Shell Install Script by Nuomiaa & CreeperKong
+----------------------------------------------------------------------
"

# 环境检查
if [ "$arch" == x86_64 ]; then
  arch=x64
  #echo "[-] x64 architecture detected"
elif [ $arch == aarch64 ]; then
  arch=arm64
  #echo "[-] 64-bit ARM architecture detected"
elif [ $arch == arm ]; then
  arch=armv7l
  #echo "[-] 32-bit ARM architecture detected"
elif [ $arch == ppc64le ]; then
  arch=ppc64le
  #echo "[-] IBM POWER architecture detected"
elif [ $arch == s390x ]; then
  arch=s390x
  #echo "[-] IBM LinuxONE architecture detected"
else
  if [ "$zh" == 1 ];
      then Red_Error "[x] 抱歉，暂不支持您的 体系架构($arch)！"
      else Red_Error "[x] Sorry, this architecture is not supported yet!"
  fi
  exit
fi

# 定义变量 Node 安装目录
node_install_path="/opt/node-$node-linux-$arch"

# 检查网络连接
if [ "$zh" == 1 ];
      then
        echo_cyan "[-] 体系架构：$arch"
        echo_cyan_n "[-] 检查网络连接(ping gitee.com)... "
      else
        echo_cyan "[-] Architecture: $arch"
        echo_cyan_n "[+] Check network connection(ping gitee.com)... "
fi
if ping -c 1 gitee.com > /dev/null;
then
    if [ "$zh" == 1 ];
          then echo_green "成功"
          else echo_green "Success"
    fi
else
    if [ "$zh" == 1 ];
          then
            echo_red "失败"
            Red_Error "[x] 无法连接到 gitee.com 代码仓库！"
          else
            echo_red "Fail"
            Red_Error "[x] Unable to connect to gitee.com repository!"
    fi
    #exit
    # 暂时注释，以防禁 ping 服务器无法安装
fi

# MCSManager 已安装
if [ -d "$mcsmanager_install_path" ]; then
  printf "\033c"
  if [ "$zh" == 1 ];
      then echo_red "----------------------------------------------------
检查到已有 MCSManager 安装在 \"$mcsmanager_install_path\"
继续安装会删除原有 MCSManager 面版的所有数据！
----------------------------------------------------
将在 10 秒后继续安装，取消请按 Ctrl + Z/C 键！"
      else echo_red "----------------------------------------------------
MCSManager is installed at \"$mcsmanager_install_path\"
Continuing the installation will delete the original MCSManager!
----------------------------------------------------
Installation will continue in 10 seconds, press Ctrl + Z/C to cancel!"
  fi
  sleep 10
fi

# 安装相关软件
if [ "$zh" == 1 ];
      then echo_cyan_n "[-] 安装相关软件(git,tar)... "
      else echo_cyan_n "[+] Installing dependent software(git,tar)... "
fi
if [ -x "$(command -v yum)" ]; then yum install -y git tar > error;
elif [ -x "$(command -v apt-get)" ]; then apt-get install -y git tar > error;
elif [ -x "$(command -v pacman)" ]; then pacman -Ryu --noconfirm git tar > error;
elif [ -x "$(command -v zypper)" ]; then zypper --non-interactive install git tar > error;
fi

# 判断相关软件是否安装成功
if [[ -x "$(command -v git)" && -x "$(command -v tar)" ]]
  then
    if [ "$zh" == 1 ];
      then echo_green "成功"
      else echo_green "Success"
    fi
  else
    if [ "$zh" == 1 ];
      then echo_red "失败"
      else echo_red "Failed"
    fi
    echo "$error"
    if [ "$zh" == 1 ];
      then Red_Error "[x] 相关软件安装失败，请手动安装 git 和 tar 软件包！"
      else Red_Error "[x] Related software installation failed, please install git and tar packages manually!"
    fi
    exit
fi


# 安装 Node 环境
Install_Node

# 安装 MCSManager
Install_MCSManager

# 创建 MCSManager 后台服务
Create_Service
