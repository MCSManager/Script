#!/bin/bash
printf "\033c"

Red_Error() {
  printf '\033[1;31;40m%b\033[0m\n' "$@"
}

echo "============= MCSManager 命令行 ===============
(1) 重启面版服务       (8) 重启守护进程
(2) 停止面版服务       (9) 停止守护进程
(3) 启动面版服务       (10) 启动守护进程
(4) 禁用面版服务       (11) 禁用守护进程
(5) 启用面版服务       (12) 启用守护进程
(6) 修改管理密码       (13) 清理面版日志
(7) 卸载管理面版       (14) 全部重启
(0) 退出
==============================================="

read -r -p "[-] 请输入命令编号: " cmd;

if [ "$cmd" ] && [ "$cmd" -gt 0 ] && [ "$cmd" -lt 15 ]; then
   echo "==============================================="
   echo "[-] 正在执行($cmd)..."
   echo "==============================================="
fi

if [ "$cmd" == 1 ]
then
  systemctl restart mcsm-web.service
elif [ "$cmd" == 2 ]
then
  systemctl stop mcsm-web.service
elif [ "$cmd" == 3 ]
then
  systemctl start mcsm-web.service
elif [ "$cmd" == 4 ]
then
  systemctl disable mcsm-web.service
elif [ "$cmd" == 5 ]
then
  systemctl enable mcsm-web.service
elif [ "$cmd" == 6 ]
then
  read -r -p "[+] 请输入新密码: " new1;

  if [ "${#new1}" -lt 6 ]; then
    echo "==============================================="
    echo "[x] 密码长度不能小于 6"
    exit
  fi

  read -r -p "[+] 请再次输入新密码: " new2;

  if [ "$new1" != "$new2" ]; then
    echo "==============================================="
    echo "[x] 两次输入的密码不一致"
    exit
  fi

  echo "[-] 修改 MCSManager-Web root 密码..."
  passWord_old=$(awk -F"\"" '/passWord/{print $4}' /opt/mcsmanager/web/data/User/root.json)
  passWord_new=$(echo -n "$new2" | md5sum | cut -d ' ' -f1)
  sed -e "s@$passWord_old@$passWord_new@g" -i /opt/mcsmanager/web/data/User/root.json

  echo "[-] 重启 MCSManager-Web 服务..."
  systemctl restart mcsm-web.service

  echo "[+] root 密码已更新！"
elif [ "$cmd" == 7 ]
then
  Red_Error "[!] 卸载后无法找回数据，请先备份必要数据！"
  read -r -p "[-] 确认已了解以上内容，我确定已备份完成 (输入yes继续卸载): " yes;
  if [ "$yes" != "yes" ]; then
    echo "==============================================="
    echo "已取消！"
    exit
  fi

  echo "[-] MCSManager 服务正在运行，停止服务..."
  systemctl stop mcsm-{daemon,web}.service
  systemctl disable mcsm-{daemon,web}.service

  echo "[x] 删除 MCSManager 服务"
  rm -f /etc/systemd/system/mcsm-daemon.service
  rm -f /etc/systemd/system/mcsm-web.service

  echo "[-] 重载服务配置文件"
  systemctl daemon-reload

  echo "[x] 删除 MCSManager 相关文件"
  rm -irf /opt/mcsmanager

  echo "[x] 删除 MCSManager-命令行 相关文件"
  rm -f /usr/local/bin/mcsm
  rm -f /opt/mcsm.sh

  echo "==============================================="
  echo -e "\033[1;32m卸载完成，感谢使用 MCSManager！\033[0m"

elif [ "$cmd" == 8 ]
then
  systemctl restart mcsm-web.service
elif [ "$cmd" == 9 ]
then
  systemctl stop mcsm-web.service
elif [ "$cmd" == 10 ]
then
  systemctl start mcsm-web.service
elif [ "$cmd" == 11 ]
then
  systemctl disable mcsm-web.service
elif [ "$cmd" == 12 ]
then
  systemctl enable mcsm-web.service
elif [ "$cmd" == 13 ]
then
  rm -ifr /opt/mcsmanager/web/logs
  mkdir -p /opt/mcsmanager/web/logs
  echo "[-] 已清空日志！"
elif [ "$cmd" == 14 ]
then
  echo "a 等于 b"
else
  echo "==============================================="
  echo "[-] 已取消！"
fi


