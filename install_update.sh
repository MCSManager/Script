#!/bin/bash

#Global arguments
mcsmanager_install_path="/opt/mcsmanager"
mcsmanager_donwload_addr="http://oss.duzuii.com/d/MCSManager/MCSManager/MCSManager-v10-linux.tar.gz"
package_name="MCSManager-v10-linux.tar.gz"
node="v20.12.2"
arch=$(uname -m)

# Default systemd user is 'mcsm'
USER="mcsm"
COMMAND="all"

# Helper Functions
usage() {
    echo "Usage: $0 [-u user] [-c command]"
    echo "  -u  Specify the user (mcsm or root), default is 'mcsm'"
    echo "  -c  Specify the command (web, daemon, or all), default is 'all'"
    exit 1
}
Red_Error() {
    echo '================================================='
    printf '\033[1;31;40m%b\033[0m\n' "$@"
    echo '================================================='
    exit 1
}
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

# Check root permission
check_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "This script must be run as root. Please use \"sudo or root user\" instead."
		exit 1
	fi
}
check_sudo
