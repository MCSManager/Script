#!/bin/bash

#Global arguments
# System architecture
arch=$(uname -m)
# Install base dir
install_base="/opt"
# MCSM install dir
mcsmanager_install_path="${install_base}/mcsmanager"
# MCSM backup dir
mcsm_backup_dir="${install_base}"
# Download URL
mcsmanager_donwload_addr="http://oss.duzuii.com/d/MCSManager/MCSManager/MCSManager-v10-linux.tar.gz"
# Node.js version to install
node="v20.12.2"
# Node.js install dir
node_install_path="${install_base}/node-$node-linux-$arch"
# MCSM Web dir name
mcsm_web="web"
# MCSM daemon dir name
mcsm_daemon="daemon"
# The date variable to be shared across functions
local current_date=$(date +%Y_%m_%d)
# MCSM local temp dir for downloaded source
mcsm_down_temp="/opt/mcsmanager_${current_date}"
# Service file for MCSCM Web
service_file_web="/etc/systemd/system/mcsm-web.service"
# Service file for MCSM daemon
service_file_daemon="/etc/systemd/system/mcsm-daemon.service"
# Default systemd user is 'mcsm'
USER="mcsm"
COMMAND="all"
# Created backup absolute path
backup_path=""

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

Install_dependencies() {
	# Install related software
	echo_cyan_n "[+] Installing dependent software (git, tar, wget)... "
	if [[ -x "$(command -v yum)" ]]; then
		yum install -y git tar wget
	elif [[ -x "$(command -v apt-get)" ]]; then
		apt-get install -y git tar wget
	elif [[ -x "$(command -v pacman)" ]]; then
		pacman -S --noconfirm git tar wget
	elif [[ -x "$(command -v zypper)" ]]; then
		zypper --non-interactive install git tar wget
	else
		echo_red "[!] Cannot find your package manager! You may need to install git, tar and wget manually!"
	fi
	
	# Determine whether the relevant software is installed successfully
	if [[ -x "$(command -v git)" && -x "$(command -v tar)" && -x "$(command -v wget)" ]]; then
		echo_green "Success"
	else
		Red_Error "[x] Failed to find git, tar and wget, please install them manually!"
	fi

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
    echo_yellow "=============== Node.js Version ==============="
    echo_yellow " node: $("$node_install_path"/bin/node -v)"
    echo_yellow " npm: v$(env "$node_install_path"/bin/node "$node_install_path"/bin/npm -v)"
    echo_yellow "=============== Node.JS Version ==============="
    echo

    sleep 3
}
# Check and download MCSM source
Check_and_download_source() {
	# Empty the temp dir if existed
	rm -rf "$mcsm_down_temp"
	mkdir -p "$mcsm_down_temp"

    # Download the archive directly into the temporary directory
    wget -O "${mcsm_down_temp}/mcsmanager.tar.gz" "$mcsmanager_download_addr"
    if [ $? -ne 0 ]; then
        echo "Download failed."
        return 1  # Exit if download fails
    fi

    # Extract the archive without changing directories
    tar -xzf "${mcsm_down_temp}/mcsmanager.tar.gz" -C "$mcsm_down_temp" --strip-components=1
    if [ $? -ne 0 ]; then
        echo "Extraction failed."
        return 1  # Exit if extraction fails
    fi

    # Clean up the downloaded tar.gz file
    rm "${mcsm_down_temp}/mcsmanager.tar.gz"

# Initialization
Initialize() {
	# Check sudo
	check_sudo
	
	# Check if install base (/opt) exist
	mkdir -p "$install_base"
	
	# Create mcsmanager path if not already
	mkdir -p "$mcsmanager_install_path"
	
	# Check dependencies
	Install_dependencies

	# Check and download MCSM source
	Check_and_download_source
	
	# Create mcsm user if needed
	if [[ "$USER" == *"mcsm"* ]]; then
		# Create the user 'mcsm' if it doesn't already exist
		if ! id "mcsm" &>/dev/null; then
			useradd mcsm
			echo "User 'mcsm' created."
		else
			echo "User 'mcsm' already exists."
		fi
	fi
}

Backup_MCSM() {
    # Ensure both directories are provided
    if [ -z "$mcsmanager_install_path" ] || [ -z "$mcsm_backup_dir" ]; then
        echo "Error: Backup or source path not set."
        return 1  # Return with error
    fi

    # Check if the source directory exists
    if [ ! -d "$mcsmanager_install_path" ]; then
        echo "Error: Source directory does not exist."
        return 1  # Return with error
    fi

    # Create backup directory (/opt) if it doesn't exist
    if [ ! -d "$mcsm_backup_dir" ]; then
        echo "Creating backup directory."
        mkdir -p "$mcsm_backup_dir"
    fi

    # Define the backup path
    backup_path="${mcsm_backup_dir}/mcsm_backup_${current_date}.tar.gz"

    # Create the backup
	echo "Creating backup..."
    tar -czf "$backup_path" -C "$mcsmanager_install_path" .

    # Check if the backup was successful
    if [ $? -eq 0 ]; then
        echo "Backup created successfully at $backup_path"
    else
        echo "Error creating backup."
        return 1  # Return with error
    fi
}
# MCSM Web Base Installation
# Assuming a fresh install (i.e. no file(s) from previous installation) and downloaded source
Install_MCSM_Web_Base() {
	# Move downloaded path
	mv "${mcsm_down_temp}/${mcsm_web}" "$web_path"
	# Move back the data directory
	rm -rf "$web_data"
	mv "${web_data_tmp}" "${web_data}"
	# Dependencies install
	cd "${web_path}" || Red_Error "[x] Failed to enter ${web_path}"
	# Install dependencies
    echo_cyan "[+] Install MCSManager-Web dependencies..."
    env "$node_install_path"/bin/node "$node_install_path"/bin/npm install --production --no-fund --no-audit &>/dev/null || Red_Error "[x] Failed to npm install in ${web_path}"
	# Return to general dir
	cd "$mcsmanager_install_path"
	# Configure ownership if needed
	if [[ "$USER" == *"mcsm"* ]]; then
		# Change file permission to mcsm user
		chown -R mcsm:mcsm "$web_path"
	fi
	chmod -R 755 "$web_path"
}
# MCSM Web Service Installation
Install_Web_Systemd() {
	echo_cyan "[+] Creating MCSManager Web service..."
	# stop and disable existing service
    systemctl disable --now mcsm-web

    # delete existing service
    rm -rf /etc/systemd/system/mcsm-web.service
    systemctl daemon-reload

	# Create the default service file
	echo "[Unit]
	Description=MCSManager-Web

	[Service]
	WorkingDirectory=${web_path}
	ExecStart=${node_install_path}/bin/node app.js
	ExecReload=/bin/kill -s QUIT \$MAINPID
	ExecStop=/bin/kill -s QUIT \$MAINPID
	Environment=\"PATH=${PATH}\"

	[Install]
	WantedBy=multi-user.target
	" >/etc/systemd/system/mcsm-web.service
	# Add user section if using mcsm user
	if [[ "$USER" == *"mcsm"* ]]; then
		# Check if the 'User=mcsm' line already exists in the service file
		if grep -q "^User=mcsm$" "$service_file"; then
			echo "The service file is configured already."
		else
			# Add 'User=mcsm' to the service file
			sed -i '/^\[Service\]$/a User=mcsm' "$service_file"
		fi
	fi
	# Reload Systemd Service
	systemctl daemon-reload
	
}

# MCSM Web Update & Installation
Install_Web_Wrapper() {
	web_path="${mcsmanager_install_path}/${mcsm_web}"
	web_data="${web_path}/data"
	web_data_tmp="${mcsmanager_install_path}/web_data_${current_date}"
	if [ -d "$web_path" ]; then
		echo_cyan "[+] Updating MCSManager Web..."
		# The backup should be created already, moving the DATA dir to /opt/mcsmanager/web_data should be fast and safe.
		# Use web_data, do not use data as in rare circumstance user may run both update at the same time.
		# Use mv command, this won't create issue in case of an incomplete previous installation (e.g. empty mcsm dir)
		mv "$web_data" "$web_data_tmp"
		# Remove the old web dir
		rm -rf "$web_path"
		
	else
		echo "The directory '$mcsmanager_install_path' does not exist."
	fi
    echo_cyan "[+] Install MCSManager Web..."
	
	# Install MCSM Web
	Install_MCSM_Web_Base
	
	# Install MCSM Web Service
	Install_Web_Systemd
}

# MCSM Daemon Base Installation
# Assuming a fresh install (i.e. no file(s) from previous installation) and downloaded source
Install_MCSM_Daemon_Base() {
	# Move downloaded path
	mv "${mcsm_down_temp}/${mcsm_daemon}" "$daemon_path"
	# Move back the data directory
	rm -rf "$daemon_data"
	mv "${web_daemon_tmp}" "${daemon_data}"
	# Dependencies install
	cd "${daemon_path}" || Red_Error "[x] Failed to enter ${daemon_path}"
	# Install dependencies
    echo_cyan "[+] Install MCSManager-Daemon dependencies..."
    env "$node_install_path"/bin/node "$node_install_path"/bin/npm install --production --no-fund --no-audit &>/dev/null || Red_Error "[x] Failed to npm install in ${daemon_path}"
	# Return to general dir
	cd "$mcsmanager_install_path"
	# Configure ownership if needed
	if [[ "$USER" == *"mcsm"* ]]; then
		# Change file permission to mcsm user
		chown -R mcsm:mcsm "$daemon_path"
	fi
	chmod -R 755 "$daemon_path"
}

# MCSM Daemon Service Installation
Install_Daemon_Systemd() {
	echo_cyan "[+] Creating MCSManager Daemon service..."
	# Create the default service file
	echo "[Unit]
	Description=MCSManager-Daemon

	[Service]
	WorkingDirectory=${daemon_path}
	ExecStart=${node_install_path}/bin/node app.js
	ExecReload=/bin/kill -s QUIT \$MAINPID
	ExecStop=/bin/kill -s QUIT \$MAINPID
	Environment=\"PATH=${PATH}\"

	[Install]
	WantedBy=multi-user.target
	" >/etc/systemd/system/mcsm-daemon.service
	# Add user section if using mcsm user
	if [[ "$USER" == *"mcsm"* ]]; then
		# Check if the 'User=mcsm' line already exists in the service file
		if grep -q "^User=mcsm$" "$service_file"; then
			echo "The service file is configured already."
		else
			# Add 'User=mcsm' to the service file
			sed -i '/^\[Service\]$/a User=mcsm' "$service_file"
		fi
	fi
	# Reload Systemd Service
	systemctl daemon-reload
	
}


########### Main Logic ################
Initialize
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
    # Backup first
	Backup_MCSM
	# Install Node.js, this is to ensure the version is up to date.
	Install_node
	# 
	
else
    echo "The directory '$mcsmanager_install_path' does not exist."
    # Logic branch when the directory does not exist
    # For example, create the directory
    echo "Creating $mcsmanager_install_path..."
fi