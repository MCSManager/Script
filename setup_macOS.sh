#!/bin/bash

# 获取脚本所在的目录作为安装目录
# 使用 dirname "$0" 获取脚本路径，然后 cd 到该目录并打印当前路径 (pwd -P 处理符号链接)
# 使用 || exit 表示如果 cd 失败就退出
INSTALL_DIR="$(cd "$(dirname "$0")" || exit; pwd -P)"
MCSM_DIR="$INSTALL_DIR/mcsmanager" # MCSManager 文件解压后的目录

echo "=================================================="
echo "  MCSManager 安装脚本 (macOS)"
echo "=================================================="
echo "安装目录: $INSTALL_DIR"
echo "注意：需要 Homebrew 和 Node.js 已安装。"
echo "=================================================="

# --- 检查必要命令 ---
echo "检查必要命令 (brew, node, npm, curl, tar, pm2)..."
if ! command -v brew &> /dev/null; then
    echo "错误: Homebrew 未找到。请先安装 Homebrew。"
    exit 1
fi
if ! command -v node &> /dev/null; then
    echo "错误: Node.js 未找到。请使用 'brew install node' 安装。"
    exit 1
fi
if ! command -v npm &> /dev/null; then
    echo "错误: npm 未找到。请确保 Node.js 安装正确。"
    exit 1
fi
if ! command -v curl &> /dev/null; then
    echo "错误: curl 未找到。"
    exit 1
fi
if ! command -v tar &> /dev/null; then
    echo "错误: tar 未找到。"
    exit 1
fi

# 检查 PM2 是否全局安装，如果没有则提示用户或尝试安装
if ! command -v pm2 &> /dev/null; then
    echo "PM2 未找到。尝试全局安装 PM2..."
    npm install -g pm2
    if ! command -v pm2 &> /dev/null; then
        echo "错误: PM2 安装失败。请手动运行 'npm install -g pm2'。"
        exit 1
    fi
    echo "PM2 安装成功。"
else
    echo "PM2 已安装。"
fi
echo "必要命令检查通过。"

# --- 提供安装选项 ---
echo "请选择安装模式:"
echo "1) 安装 Web 面板 + 节点 (Daemon) (推荐)"
echo "2) 只安装节点 (Daemon)"
read -p "请输入选项 (1 或 2): " choice

# 验证用户输入
if [[ "$choice" != "1" && "$choice" != "2" ]]; then
    echo "无效的输入。请重新运行脚本并选择 1 或 2。"
    exit 1
fi

# --- 创建安装目录 (脚本所在目录已存在，但需要确保是可写) ---
echo "使用安装目录: $INSTALL_DIR"
if [ ! -w "$INSTALL_DIR" ]; then
    echo "错误: 脚本所在目录 $INSTALL_DIR 不可写。请检查权限。"
    exit 1
fi
echo "目录权限检查通过。"

# --- 下载 MCSManager Release ---
# 使用 Linux 版本，因为 Node.js 部分是跨平台的，且 release 包同时包含 web 和 daemon
MCSM_TAR_URL="https://github.com/MCSManager/MCSManager/releases/latest/download/mcsmanager_linux_release.tar.gz"
MCSM_TAR_FILE="$INSTALL_DIR/mcsmanager_linux_release.tar.gz"

echo "下载 MCSManager Release ($MCSM_TAR_URL) 到 $MCSM_TAR_FILE"
# 使用 curl 下载，-L 跟随重定向，-o 指定输出文件，-f 在 HTTP 错误时退出
curl -L -f "$MCSM_TAR_URL" -o "$MCSM_TAR_FILE"
if [ $? -ne 0 ]; then
    echo "错误: 下载失败。请检查网络连接或 URL。"
    exit 1
fi
echo "下载成功。"

# --- 解压 MCSManager Release ---
echo "解压 $MCSM_TAR_FILE 到 $INSTALL_DIR"
# -C 指定解压目录
tar -zxf "$MCSM_TAR_FILE" -C "$INSTALL_DIR"
if [ $? -ne 0 ]; then
    echo "错误: 解压失败。"
    # 尝试删除可能不完整的目录
    rm -rf "$MCSM_DIR"
    exit 1
fi

# 检查解压是否成功创建了 mcsmanager 目录
if [ ! -d "$MCSM_DIR" ]; then
    echo "错误: 解压失败。未找到目录 $MCSM_DIR。"
    exit 1
fi
echo "解压成功。"

# 清理下载的压缩包
echo "移除下载的压缩包: $MCSM_TAR_FILE"
rm "$MCSM_TAR_FILE"

# --- 进入 MCSManager 目录并安装依赖 ---
echo "切换到目录: $MCSM_DIR"
cd "$MCSM_DIR"
if [ $? -ne 0 ]; then
    echo "错误: 无法切换到目录 $MCSM_DIR。"
    exit 1
fi

echo "运行 ./install.sh 安装依赖..."
# 使用 bash 确保脚本正确执行
bash ./install.sh
if [ $? -ne 0 ]; then
    echo "错误: ./install.sh 运行失败。请检查输出信息。"
    exit 1
fi
echo "依赖安装步骤完成。"

# --- 使用 PM2 启动 MCSManager 进程并配置自启动 ---
echo "使用 PM2 启动 MCSManager 进程..."

# 停止并删除旧的 PM2 进程（如果存在）
echo "停止并删除旧的 PM2 进程 (如果存在)..."
pm2 stop MCSManager-Daemon &> /dev/null
pm2 delete MCSManager-Daemon &> /dev/null
pm2 stop MCSManager-Web &> /dev/null
pm2 delete MCSManager-Web &> /dev/null
sleep 1 # 等待片刻确保进程停止

# 启动 Daemon
echo "启动 MCSManager Daemon..."
pm2 start ./start-daemon.sh --name "MCSManager-Daemon" --output "$INSTALL_DIR/daemon_output.log" --error "$INSTALL_DIR/daemon_error.log"
sleep 3 # 等待片刻让 PM2 启动进程
if ! pm2 status | grep -q "MCSManager-Daemon"; then
    echo "错误: PM2 未能成功启动 MCSManager-Daemon。"
    pm2 logs MCSManager-Daemon
    exit 1
fi
echo "MCSManager Daemon 已通过 PM2 启动。"
echo "查看 Daemon 状态: pm2 status MCSManager-Daemon"
echo "查看 Daemon 日志: pm2 logs MCSManager-Daemon"
echo "Daemon 默认监听端口: 24444"


# 如果选择安装 Web 面板
if [ "$choice" == "1" ]; then
    echo ""
    echo "启动 MCSManager Web 面板..."
    pm2 start ./start-web.sh --name "MCSManager-Web" --output "$INSTALL_DIR/web_output.log" --error "$INSTALL_DIR/web_error.log"
    sleep 3 # 等待片刻让 PM2 启动进程
    if ! pm2 status | grep -q "MCSManager-Web"; then
        echo "错误: PM2 未能成功启动 MCSManager-Web。"
        pm2 logs MCSManager-Web
        # 注意：这里不退出，因为 Daemon 可能已经启动成功
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
# 这个命令会生成一个 launchd 配置文件，并通常会输出一条需要用户手动运行的命令
# 运行一次即可，它配置的是 PM2 daemon 本身，而不是 MCSM 进程
pm2 startup launchd

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

echo "--- PM2 控制命令参考 ---"
echo "查看所有 MCSManager 进程状态:"
echo "  pm2 status"
echo ""
echo "--- Daemon (节点) ---"
echo "进程名: MCSManager-Daemon"
echo "日志文件: $INSTALL_DIR/daemon_output.log, $INSTALL_DIR/daemon_error.log"
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
    echo "日志文件: $INSTALL_DIR/web_output.log, $INSTALL_DIR/web_error.log"
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
echo "请查找上面 'pm2 startup launchd' 命令的输出，它会显示一条需要您手动执行的命令，通常以 'sudo env PATH=...' 开头。"
echo "请复制并粘贴该命令到终端中运行，以确保 PM2 Daemon 本身在系统重启后自动启动，从而管理 MCSManager 进程。"
echo "示例 (请运行实际输出的命令):"
echo "  sudo env PATH=\$PATH:/usr/local/bin /Users/youruser/.nvm/versions/node/vX.Y.Z/bin/pm2 startup launchd -u youruser --hp /Users/youruser"
echo ""
echo "=================================================="

exit 0

