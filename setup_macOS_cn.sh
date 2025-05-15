#!/bin/bash

INSTALL_DIR="$(cd "$(dirname "$0")" || exit; pwd -P)"
MCSM_DIR="$INSTALL_DIR/mcsmanager"

echo "=================================================="
echo "  MCSManager 安装脚本 (macOS)"
echo "=================================================="
echo "安装目录: $INSTALL_DIR"
echo "注意：需要 Homebrew 和 Node.js 已安装。"
echo "=================================================="

echo "将自动检测并安装所需依赖 (brew, node, npm, curl, tar, pm2)..."

if ! command -v brew &> /dev/null; then
    echo "未检测到 Homebrew，正在自动安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if ! command -v brew &> /dev/null; then
        echo "错误: Homebrew 安装失败。"
        exit 1
    fi
fi

if ! command -v node &> /dev/null; then
    echo "未检测到 Node.js，正在通过 Homebrew 安装 Node.js..."
    brew install node
    if ! command -v node &> /dev/null; then
        echo "错误: Node.js 安装失败。"
        exit 1
    fi
fi

if ! command -v npm &> /dev/null; then
    echo "未检测到 npm，正在通过 Homebrew 重新安装 Node.js..."
    brew install node
    if ! command -v npm &> /dev/null; then
        echo "错误: npm 安装失败。"
        exit 1
    fi
fi

if ! command -v curl &> /dev/null; then
    echo "未检测到 curl，正在通过 Homebrew 安装 curl..."
    brew install curl
    if ! command -v curl &> /dev/null; then
        echo "错误: curl 安装失败。"
        exit 1
    fi
fi

if ! command -v tar &> /dev/null; then
    echo "未检测到 tar，正在通过 Homebrew 安装 tar..."
    brew install tar
    if ! command -v tar &> /dev/null; then
        echo "错误: tar 安装失败。"
        exit 1
    fi
fi

if ! command -v pm2 &> /dev/null; then
    echo "未检测到 PM2，正在全局安装 PM2..."
    npm install -g pm2
    if ! command -v pm2 &> /dev/null; then
        echo "错误: PM2 安装失败。请手动运行 'npm install -g pm2'。"
        exit 1
    fi
    echo "PM2 安装成功。"
else
    echo "PM2 已安装。"
fi
echo "所有依赖检测并安装完成。"

echo "请选择安装模式："
echo "1) 安装 Web 面板 + 节点 (Daemon) (推荐)"
echo "2) 只安装节点 (Daemon)"
read -p "请输入选项 (1 或 2): " choice
if [[ "$choice" != "1" && "$choice" != "2" ]]; then
    echo "无效的输入。请重新运行脚本并选择 1 或 2。"
    exit 1
fi

echo "使用安装目录: $INSTALL_DIR"
if [ ! -w "$INSTALL_DIR" ]; then
    echo "错误: 脚本所在目录 $INSTALL_DIR 不可写。请检查权限。"
    exit 1
fi
echo "目录权限检查通过。"

MCSM_TAR_URL="https://github.com/MCSManager/MCSManager/releases/latest/download/mcsmanager_linux_release.tar.gz"
MCSM_TAR_FILE="$INSTALL_DIR/mcsmanager_linux_release.tar.gz"

echo "下载 MCSManager Release ($MCSM_TAR_URL) 到 $MCSM_TAR_FILE"
curl -L -f "$MCSM_TAR_URL" -o "$MCSM_TAR_FILE"
if [ $? -ne 0 ]; then
    echo "错误: 下载失败。请检查网络连接或 URL。"
    exit 1
fi
echo "下载成功。"

echo "解压 $MCSM_TAR_FILE 到 $INSTALL_DIR"
tar -zxf "$MCSM_TAR_FILE" -C "$INSTALL_DIR"
if [ $? -ne 0 ]; then
    echo "错误: 解压失败。"
    rm -rf "$MCSM_DIR"
    exit 1
fi

if [ ! -d "$MCSM_DIR" ]; then
    echo "错误: 解压失败。未找到目录 $MCSM_DIR。"
    exit 1
fi
echo "解压成功。"

echo "移除下载的压缩包: $MCSM_TAR_FILE"
rm "$MCSM_TAR_FILE"

echo "切换到目录: $MCSM_DIR"
cd "$MCSM_DIR"
if [ $? -ne 0 ]; then
    echo "错误: 无法切换到目录 $MCSM_DIR。"
    exit 1
fi

echo "运行 ./install.sh 安装依赖..."
bash ./install.sh
if [ $? -ne 0 ]; then
    echo "错误: ./install.sh 运行失败。请检查输出信息。"
    exit 1
fi
echo "依赖安装步骤完成。"

echo "使用 PM2 启动 MCSManager 进程..."

echo "停止并删除旧的 PM2 进程 (如果存在)..."
pm2 stop MCSManager-Daemon &> /dev/null
pm2 delete MCSManager-Daemon &> /dev/null
pm2 stop MCSManager-Web &> /dev/null
pm2 delete MCSManager-Web &> /dev/null
sleep 1

echo "启动 MCSManager Daemon..."
pm2 start ./start-daemon.sh --name "MCSManager-Daemon" --output "$MCSM_DIR/daemon_output.log" --error "$MCSM_DIR/daemon_error.log"
sleep 3
if ! pm2 status | grep -q "MCSManager-Daemon"; then
    echo "错误: PM2 未能成功启动 MCSManager-Daemon。"
    pm2 logs MCSManager-Daemon
    exit 1
fi
echo "MCSManager Daemon 已通过 PM2 启动。"
echo "查看 Daemon 状态: pm2 status MCSManager-Daemon"
echo "查看 Daemon 日志: pm2 logs MCSManager-Daemon"
echo "Daemon 默认监听端口: 24444"

if [ "$choice" == "1" ]; then
    echo ""
    echo "启动 MCSManager Web 面板..."
    pm2 start ./start-web.sh --name "MCSManager-Web" --output "$MCSM_DIR/web_output.log" --error "$MCSM_DIR/web_error.log"
    sleep 3
    if ! pm2 status | grep -q "MCSManager-Web"; then
        echo "错误: PM2 未能成功启动 MCSManager-Web。"
        pm2 logs MCSManager-Web
        echo "请手动检查 MCSManager-Web 的问题。"
    else
        echo "MCSManager Web 面板已通过 PM2 启动。"
        echo "查看 Web 状态: pm2 status MCSManager-Web"
        echo "查看 Web 日志: pm2 logs MCSManager-Web"
        echo "Web 默认监听端口: 23333"
    fi
fi

echo ""
echo "配置 PM2 自启动 (使用 launchd)..."
startup_cmd=$(pm2 startup launchd | grep 'sudo' | sed 's/^.*\(sudo.*\)$/\1/')
if [ -n "$startup_cmd" ]; then
    echo "自动执行 PM2 自启动命令 请在下方输入密码(非明文)"
    eval $startup_cmd
    if [ $? -eq 0 ]; then
        echo "PM2 自启动配置已自动完成。"
    else
        echo "自动执行 PM2 自启动命令失败，请手动执行以下命令："
        echo "  $startup_cmd"
    fi
else
    echo "未能自动获取 PM2 自启动命令，请手动运行 'pm2 startup launchd' 并按提示操作。"
fi

echo ""
echo "=================================================="
if [ "$choice" == "1" ]; then
    echo "       MCSManager Web 面板 + 节点 安装完成！"
else
    echo "       MCSManager 节点 (Daemon) 安装完成！"
fi
echo "=================================================="
echo "安装目录: $INSTALL_DIR"
echo ""

GLOBAL_JSON="$MCSM_DIR/daemon/data/Config/global.json"
if [ -f "$GLOBAL_JSON" ]; then
    NODE_KEY=$(grep '"key"' "$GLOBAL_JSON" | head -n1 | sed 's/.*"key": *"\([^"]*\)".*/\1/')
    if [ -n "$NODE_KEY" ]; then
        echo "请及时复制以下远程节点密钥，用于连接节点："
        echo "节点 Key: $NODE_KEY"
    else
        echo "未能自动获取节点 Key，请手动查看 $GLOBAL_JSON"
    fi
else
    echo "未找到 $GLOBAL_JSON，无法获取节点 Key。"
fi

echo ""
echo "--- PM2 控制命令参考 ---"
echo "查看所有 MCSManager 进程状态:"
echo "  pm2 status"
echo ""
echo "--- Daemon (节点) ---"
echo "进程名: MCSManager-Daemon"
echo "日志文件: $MCSM_DIR/daemon_output.log, $MCSM_DIR/daemon_error.log"
echo "启动 Daemon: pm2 start MCSManager-Daemon"
echo "停止 Daemon: pm2 stop MCSManager-Daemon"
echo "重启 Daemon: pm2 restart MCSManager-Daemon"
echo "删除 Daemon (从 PM2 列表移除): pm2 delete MCSManager-Daemon"
echo "查看 Daemon 日志: pm2 logs MCSManager-Daemon"
echo "查看 Daemon 实时日志: pm2 logs MCSManager-Daemon --follow"
echo ""

if [ "$choice" == "1" ]; then
    echo "--- Web 面板 ---"
    echo "进程名: MCSManager-Web"
    echo "日志文件: $MCSM_DIR/web_output.log, $MCSM_DIR/web_error.log"
    echo "启动 Web: pm2 start MCSManager-Web"
    echo "停止 Web: pm2 stop MCSManager-Web"
    echo "重启 Web: pm2 restart MCSManager-Web"
    echo "删除 Web (从 PM2 列表移除): pm2 delete MCSManager-Web"
    echo "查看 Web 日志: pm2 logs MCSManager-Web"
    echo "查看 Web 实时日志: pm2 logs MCSManager-Web --follow"
    echo ""
    echo "默认访问地址: http://localhost:23333"
fi

echo "--- 重要：完成自启动设置 ---"
echo "PM2 自启动配置已自动尝试执行。若有报错，请参考上方命令手动执行。"
echo "=================================================="

exit 0

