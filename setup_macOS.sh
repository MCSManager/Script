#!/bin/bash

INSTALL_DIR="$(cd "$(dirname "$0")" || exit; pwd -P)"
MCSM_DIR="$INSTALL_DIR/mcsmanager"

echo "=================================================="
echo "  MCSManager Installation Script (macOS)"
echo "=================================================="
echo "Install directory: $INSTALL_DIR"
echo "Note: Homebrew and Node.js are required."
echo "=================================================="

echo "Automatically checking and installing required dependencies (brew, node, npm, curl, tar, pm2)..."

if ! command -v brew &> /dev/null; then
    echo "Homebrew not found, installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew installation failed."
        exit 1
    fi
fi

if ! command -v node &> /dev/null; then
    echo "Node.js not found, installing Node.js via Homebrew..."
    brew install node
    if ! command -v node &> /dev/null; then
        echo "Error: Node.js installation failed."
        exit 1
    fi
fi

if ! command -v npm &> /dev/null; then
    echo "npm not found, reinstalling Node.js via Homebrew..."
    brew install node
    if ! command -v npm &> /dev/null; then
        echo "Error: npm installation failed."
        exit 1
    fi
fi

if ! command -v curl &> /dev/null; then
    echo "curl not found, installing curl via Homebrew..."
    brew install curl
    if ! command -v curl &> /dev/null; then
        echo "Error: curl installation failed."
        exit 1
    fi
fi

if ! command -v tar &> /dev/null; then
    echo "tar not found, installing tar via Homebrew..."
    brew install tar
    if ! command -v tar &> /dev/null; then
        echo "Error: tar installation failed."
        exit 1
    fi
fi

if ! command -v pm2 &> /dev/null; then
    echo "PM2 not found, installing PM2 globally..."
    npm install -g pm2
    if ! command -v pm2 &> /dev/null; then
        echo "Error: PM2 installation failed. Please run 'npm install -g pm2' manually."
        exit 1
    fi
    echo "PM2 installed successfully."
else
    echo "PM2 is already installed."
fi
echo "All dependencies checked and installed."

echo "Please select installation mode:"
echo "1) Install Web Panel + Node (Daemon) (recommended)"
echo "2) Install Node (Daemon) only"
read -p "Enter your choice (1 or 2): " choice
if [[ "$choice" != "1" && "$choice" != "2" ]]; then
    echo "Invalid input. Please rerun the script and select 1 or 2."
    exit 1
fi

echo "Using install directory: $INSTALL_DIR"
if [ ! -w "$INSTALL_DIR" ]; then
    echo "Error: $INSTALL_DIR is not writable. Please check permissions."
    exit 1
fi
echo "Directory permission check passed."

MCSM_TAR_URL="https://github.com/MCSManager/MCSManager/releases/latest/download/mcsmanager_linux_release.tar.gz"
MCSM_TAR_FILE="$INSTALL_DIR/mcsmanager_linux_release.tar.gz"

echo "Downloading MCSManager Release ($MCSM_TAR_URL) to $MCSM_TAR_FILE"
curl -L -f "$MCSM_TAR_URL" -o "$MCSM_TAR_FILE"
if [ $? -ne 0 ]; then
    echo "Error: Download failed. Please check your network or the URL."
    exit 1
fi
echo "Download successful."

echo "Extracting $MCSM_TAR_FILE to $INSTALL_DIR"
tar -zxf "$MCSM_TAR_FILE" -C "$INSTALL_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Extraction failed."
    rm -rf "$MCSM_DIR"
    exit 1
fi

if [ ! -d "$MCSM_DIR" ]; then
    echo "Error: Extraction failed. Directory $MCSM_DIR not found."
    exit 1
fi
echo "Extraction successful."

echo "Removing downloaded archive: $MCSM_TAR_FILE"
rm "$MCSM_TAR_FILE"

echo "Changing to directory: $MCSM_DIR"
cd "$MCSM_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to change directory to $MCSM_DIR."
    exit 1
fi

echo "Running ./install.sh to install dependencies..."
bash ./install.sh
if [ $? -ne 0 ]; then
    echo "Error: ./install.sh failed. Please check the output."
    exit 1
fi
echo "Dependency installation completed."

echo "Starting MCSManager processes with PM2..."

echo "Stopping and deleting old PM2 processes (if any)..."
pm2 stop MCSManager-Daemon &> /dev/null
pm2 delete MCSManager-Daemon &> /dev/null
pm2 stop MCSManager-Web &> /dev/null
pm2 delete MCSManager-Web &> /dev/null
sleep 1

echo "Starting MCSManager Daemon..."
pm2 start ./start-daemon.sh --name "MCSManager-Daemon" --output "$MCSM_DIR/daemon_output.log" --error "$MCSM_DIR/daemon_error.log"
sleep 3
if ! pm2 status | grep -q "MCSManager-Daemon"; then
    echo "Error: PM2 failed to start MCSManager-Daemon."
    pm2 logs MCSManager-Daemon
    exit 1
fi
echo "MCSManager Daemon started with PM2."
echo "Check Daemon status: pm2 status MCSManager-Daemon"
echo "Check Daemon logs: pm2 logs MCSManager-Daemon"
echo "Daemon default port: 24444"

if [ "$choice" == "1" ]; then
    echo ""
    echo "Starting MCSManager Web Panel..."
    pm2 start ./start-web.sh --name "MCSManager-Web" --output "$MCSM_DIR/web_output.log" --error "$MCSM_DIR/web_error.log"
    sleep 3
    if ! pm2 status | grep -q "MCSManager-Web"; then
        echo "Error: PM2 failed to start MCSManager-Web."
        pm2 logs MCSManager-Web
        echo "Please check the MCSManager-Web issue manually."
    else
        echo "MCSManager Web Panel started with PM2."
        echo "Check Web status: pm2 status MCSManager-Web"
        echo "Check Web logs: pm2 logs MCSManager-Web"
        echo "Web default port: 23333"
    fi
fi

echo ""
echo "Configuring PM2 startup (using launchd)..."
startup_cmd=$(pm2 startup launchd | grep 'sudo' | sed 's/^.*\(sudo.*\)$/\1/')
if [ -n "$startup_cmd" ]; then
    echo "Executing PM2 startup command automatically..."
    eval $startup_cmd
    if [ $? -eq 0 ]; then
        echo "PM2 startup configuration completed automatically."
    else
        echo "Failed to execute PM2 startup command automatically. Please run the following command manually:"
        echo "  $startup_cmd"
    fi
else
    echo "Failed to get PM2 startup command automatically. Please run 'pm2 startup launchd' and follow the instructions."
fi

echo ""
echo "=================================================="
if [ "$choice" == "1" ]; then
    echo "       MCSManager Web Panel + Node installation completed!"
else
    echo "       MCSManager Node (Daemon) installation completed!"
fi
echo "=================================================="
echo "Install directory: $INSTALL_DIR"
echo ""

GLOBAL_JSON="$MCSM_DIR/daemon/data/Config/global.json"
if [ -f "$GLOBAL_JSON" ]; then
    NODE_KEY=$(grep '"key"' "$GLOBAL_JSON" | head -n1 | sed 's/.*"key": *"\([^"]*\)".*/\1/')
    if [ -n "$NODE_KEY" ]; then
        echo "Please copy the following remote node key for connecting this node:"
        echo "Node Key: $NODE_KEY"
    else
        echo "Failed to automatically get node key, please check $GLOBAL_JSON manually."
    fi
else
    echo "File $GLOBAL_JSON not found, unable to get node key."
fi

echo ""
echo "--- PM2 Command Reference ---"
echo "Check all MCSManager process status:"
echo "  pm2 status"
echo ""
echo "--- Daemon (Node) ---"
echo "Process name: MCSManager-Daemon"
echo "Log files: $MCSM_DIR/daemon_output.log, $MCSM_DIR/daemon_error.log"
echo "Start Daemon: pm2 start MCSManager-Daemon"
echo "Stop Daemon: pm2 stop MCSManager-Daemon"
echo "Restart Daemon: pm2 restart MCSManager-Daemon"
echo "Delete Daemon (remove from PM2): pm2 delete MCSManager-Daemon"
echo "View Daemon logs: pm2 logs MCSManager-Daemon"
echo "View Daemon live logs: pm2 logs MCSManager-Daemon --follow"
echo ""

if [ "$choice" == "1" ]; then
    echo "--- Web Panel ---"
    echo "Process name: MCSManager-Web"
    echo "Log files: $MCSM_DIR/web_output.log, $MCSM_DIR/web_error.log"
    echo "Start Web: pm2 start MCSManager-Web"
    echo "Stop Web: pm2 stop MCSManager-Web"
    echo "Restart Web: pm2 restart MCSManager-Web"
    echo "Delete Web (remove from PM2): pm2 delete MCSManager-Web"
    echo "View Web logs: pm2 logs MCSManager-Web"
    echo "View Web live logs: pm2 logs MCSManager-Web --follow"
    echo ""
    echo "Default access: http://localhost:23333"
fi

echo "--- IMPORTANT: Complete PM2 Startup Setup ---"
echo "PM2 startup configuration has been attempted automatically. If there are errors, please refer to the command above and run it manually."
echo "=================================================="

exit 0

