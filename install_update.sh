#!/bin/bash

#Global arguments
#MCSM install dir
mcsmanager_install_path="/opt/mcsmanager"
#MCSM backup dir
mcsm_backup_dir="/opt/"
#Created backup absolute path
backup_path=""
#Download URL
mcsmanager_donwload_addr="http://oss.duzuii.com/d/MCSManager/MCSManager/MCSManager-v10-linux.tar.gz"
#File name
package_name="MCSManager-v10-linux.tar.gz"
#Node.js version to install
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

Install_node() {
    echo_cyan_n "[+] Install Node.js environment...\n"

    rm -irf "$node_install_path"

    cd /opt || Red_Error "[x] Failed to enter /opt"

    rm -rf "node-$node-linux-$arch.tar.gz"

    wget "https://nodejs.org/dist/$node/node-$node-linux-$arch.tar.gz" || Red_Error "[x] Failed to download node release"

    tar -zxf "node-$node-linux-$arch.tar.gz" || Red_Error "[x] Failed to untar node"

    rm -rf "node-$node-linux-$arch.tar.gz"

    if [[ -f "$node_install_path"/bin/node ]] && [[ "$("$node_install_path"/bin/node -v)" == "$node" ]]; then
        echo_green "Success"
    else
        Red_Error "[x] Node installation failed!"
    fi

    echo
    echo_yellow "=============== Node.JS Version ==============="
    echo_yellow " node: $("$node_install_path"/bin/node -v)"
    echo_yellow " npm: v$(env "$node_install_path"/bin/node "$node_install_path"/bin/npm -v)"
    echo_yellow "=============== Node.JS Version ==============="
    echo

    sleep 3
}

# Check root permission
check_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "This script must be run as root. Please use \"sudo or root user\" instead."
		exit 1
	fi
}
check_sudo

# Parse provided arguments
while getopts "u:c:" opt; do
    case ${opt} in
        u )
            if [[ "${OPTARG}" == "mcsm" || "${OPTARG}" == "root" ]]; then
                user="${OPTARG}"
            else
                echo "Invalid user specified."
                usage
            fi
            ;;
        c )
            if [[ "${OPTARG}" == "web" || "${OPTARG}" == "daemon" || "${OPTARG}" == "all" ]]; then
                command="${OPTARG}"
            else
                echo "Invalid command specified."
                usage
            fi
            ;;
        \? )
            usage
            ;;
        : )
            echo "Option -$OPTARG requires an argument."
            usage
            ;;
    esac
done

# Logic for different users
case ${USER} in
  root)
    ;;
  mcsm)
    ;;
  *)
    echo "Unknown user: ${USER}. Using default user mcsm..."
    ;;
esac


# Check if the mcsmanager_install_path exists
if [ -d "$mcsmanager_install_path" ]; then
    echo "The directory '$mcsmanager_install_path' exists."
    # Logic branch when the directory exists
    # For example, list the contents
    echo "Listing contents of $mcsmanager_install_path:"
    ls -l "$directory"
else
    echo "The directory '$mcsmanager_install_path' does not exist."
    # Logic branch when the directory does not exist
    # For example, create the directory
    echo "Creating $mcsmanager_install_path..."
fi