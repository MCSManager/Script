#!/bin/bash

#Global varialbles
# System architecture
arch=$(uname -m)
# Install base dir
install_base="/opt"
# MCSM install dir
mcsmanager_install_path="${install_base}/mcsmanager"
# MCSM backup dir during upgrade
mcsm_backup_dir="${install_base}"
# Download URL
mcsmanager_download_addr="https://github.com/MCSManager/MCSManager/releases/latest/download/mcsmanager_linux_release.tar.gz "
# Node.js version to install
node="v20.12.2"
# MCSM Web dir name
mcsm_web="web"
# MCSM daemon dir name
mcsm_daemon="daemon"
# The date variable to be shared across functions
current_date=$(date +%Y_%m_%d)
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
# Downloaded package name
package_name="${mcsmanager_download_addr##*/}"
# Node.js install dir
node_install_path=""

# Helper Functions
Usage() {
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
Echo_Cyan() {
    printf '\033[1;36m%b\033[0m\n' "$@"
}
Echo_Red() {
    printf '\033[1;31m%b\033[0m\n' "$@"
}

Echo_Green() {
    printf '\033[1;32m%b\033[0m\n' "$@"
}

Echo_Cyan_N() {
    printf '\033[1;36m%b\033[0m' "$@"
}

Echo_Yellow() {
    printf '\033[1;33m%b\033[0m\n' "$@"
}

# Check root permission
Check_Sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "This script must be run as root. Please use \"sudo or root user\" instead."
		exit 1
	fi
}

Install_Dependencies() {
	# Install related software
	Echo_Cyan "[+] Installing dependent software (git, tar, wget)... "
	if [[ -x "$(command -v yum)" ]]; then
		yum install -y git tar wget
	elif [[ -x "$(command -v apt-get)" ]]; then
		apt-get install -y git tar wget
	elif [[ -x "$(command -v pacman)" ]]; then
		pacman -S --noconfirm git tar wget
	elif [[ -x "$(command -v zypper)" ]]; then
		zypper --non-interactive install git tar wget
	else
		Echo_Red "[!] Cannot find your package manager! You may need to install git, tar and wget manually!"
	fi
	
	# Determine whether the relevant software is installed successfully
	if [[ -x "$(command -v git)" && -x "$(command -v tar)" && -x "$(command -v wget)" ]]; then
		Echo_Green "Success"
	else
		Red_Error "[x] Failed to find git, tar and wget, please install them manually!"
	fi

}

Install_Node() {
    if [[ -f "$node_install_path"/bin/node ]] && [[ "$("$node_install_path"/bin/node -v)" == "$node" ]]; then
        Echo_Green "Desired Node.js is already installed at the target dir, bypassing installation..."
    else	
        Echo_Cyan_N "[+] Install Node.js environment...\n"

		rm -irf "$node_install_path"

		cd /opt || Red_Error "[x] Failed to enter /opt"

		rm -rf "node-$node-linux-$arch.tar.gz"

		wget "https://nodejs.org/dist/$node/node-$node-linux-$arch.tar.gz" || Red_Error "[x] Failed to download node release"

		tar -zxf "node-$node-linux-$arch.tar.gz" || Red_Error "[x] Failed to untar node"

		rm -rf "node-$node-linux-$arch.tar.gz"

		if [[ -f "$node_install_path"/bin/node ]] && [[ "$("$node_install_path"/bin/node -v)" == "$node" ]]; then
			Echo_Green "Success"
		else	
			Red_Error "[x] Node installation failed!"
		fi
    fi
    

    echo
    Echo_Yellow "=============== Node.js Version ==============="
    Echo_Yellow " node: $("$node_install_path"/bin/node -v)"
    Echo_Yellow " npm: v$(env "$node_install_path"/bin/node "$node_install_path"/bin/npm -v)"
    Echo_Yellow "=============== Node.js Version ==============="
    echo
    sleep 1
}
# Check and download MCSM source
Check_And_Download_Source() {
	# Empty the temp dir if existed
	rm -rf "$mcsm_down_temp"
	mkdir -p "$mcsm_down_temp"

    # Download the archive directly into the temporary directory
    wget -O "${mcsm_down_temp}/${package_name}" "$mcsmanager_download_addr"  || Red_Error "[x] Failed to download MCSManager releases..."
    if [ $? -ne 0 ]; then
        Red_Error "MCSManager Download failed."
    fi

    # Extract the archive without changing directories
    tar -xzf "${mcsm_down_temp}/${package_name}" -C "$mcsm_down_temp"
    if [ $? -ne 0 ]; then
        Red_Error  "Extraction failed."
    fi

    # Clean up the downloaded tar.gz file
    rm "${mcsm_down_temp}/${package_name}"
}
# Detect architecture
Detect_Architecture() {
	if [[ $arch == x86_64 ]]; then
		arch="x64"
		#echo "[-] x64 architecture detected"
	elif [[ $arch == aarch64 ]]; then
		arch="arm64"
		#echo "[-] 64-bit ARM architecture detected"
	elif [[ $arch == arm ]]; then
		arch="armv7l"
		#echo "[-] 32-bit ARM architecture detected"
	elif [[ $arch == ppc64le ]]; then
		arch="ppc64le"
		#echo "[-] IBM POWER architecture detected"
	elif [[ $arch == s390x ]]; then
		arch="s390x"
		#echo "[-] IBM LinuxONE architecture detected"
	else
		Red_Error "[x] Sorry, this architecture is not supported yet!\n[x]Please try to install manually: https://github.com/MCSManager/MCSManager#linux"
	fi
	
	node_install_path="${install_base}/node-$node-linux-$arch"
}
# Initialization
Initialize() {
	Echo_Cyan "+----------------------------------------------------------------------
| MCSManager V10 Installation & Upgrading Script
+----------------------------------------------------------------------
	"

	# Check sudo
	Check_Sudo
	
	# Update architecture
	Detect_Architecture
	
	# Check if install base (/opt) exist
	mkdir -p "$install_base"
	
	# Check dependencies
	Install_Dependencies

	# Check and download MCSM source
	Check_And_Download_Source
	
	# Parse input arguments
	Parse_Arguments "$@"

	# Create mcsm user if needed
	if [[ "$USER" == *"mcsm"* ]]; then
		# Create the user 'mcsm' if it doesn't already exist
		if ! id "mcsm" &>/dev/null; then
			/usr/sbin/useradd mcsm
			Echo_Green "User 'mcsm' created."
		else
			Echo_Yellow "User 'mcsm' already exists."
		fi
	fi
}

Backup_MCSM() {
    # Ensure both directories are provided
    if [ -z "$mcsmanager_install_path" ] || [ -z "$mcsm_backup_dir" ]; then
        Red_Error  "Error: Backup or source path not set."
    fi

    # Check if the source directory exists
    if [ ! -d "$mcsmanager_install_path" ]; then
        Red_Error  "Error: Source directory does not exist."
    fi

    # Create backup directory (/opt) if it doesn't exist
    if [ ! -d "$mcsm_backup_dir" ]; then
        Echo_Yellow "Creating backup directory."
        mkdir -p "$mcsm_backup_dir"
    fi

    # Define the backup path
    backup_path="${mcsm_backup_dir}/mcsm_backup_${current_date}.tar.gz"

    # Create the backup
	Echo_Yellow "Creating backup..."
    #tar -czf "$backup_path" -C "$mcsmanager_install_path" .
	tar -czf "$backup_path" -C "$(dirname "$mcsmanager_install_path")" "$(basename "$mcsmanager_install_path")"


    # Check if the backup was successful
    if [ $? -eq 0 ]; then
        Echo_Green "Successfully created backup at $backup_path"
    else
        Red_Error  "Error creating backup."
    fi
}
# MCSM Web Base Installation
# Assuming a fresh install (i.e. no file(s) from previous installation) and downloaded source
Install_MCSM_Web_Base() {
	# Move downloaded path
	mv "${mcsm_down_temp}/${mcsm_web}" "$web_path" ||
	# Move helper file(s)
	mv "${mcsm_down_temp}/start-web.sh" "${mcsmanager_install_path}/start-web.sh"
	# Move back the data directory only if existed
	if [ -d "$web_data_tmp" ]; then
		rm -rf "$web_data"
		mv "${web_data_tmp}" "${web_data}"
	fi
	# Dependencies install
	cd "${web_path}" || Red_Error "[x] Failed to enter ${web_path}"
	# Install dependencies
    Echo_Cyan "[+] Install MCSManager-Web dependencies..."
    env "$node_install_path"/bin/node "$node_install_path"/bin/npm install --production --no-fund --no-audit &>/dev/null || Red_Error "[x] Failed to npm install in ${web_path}"
	# Return to general dir
	cd "$mcsmanager_install_path"
	# Configure ownership if needed
	if [[ "$USER" == *"mcsm"* ]]; then
		# Change file permission to mcsm user
		chown -R mcsm:mcsm "$web_path"
	else
		# Change file permission to root user
		chown -R root:root "$web_path"
	fi
	chmod -R 755 "$web_path"
}
# MCSM Web Service Installation
Install_Web_Systemd() {
	Echo_Cyan "[+] Creating MCSManager Web service..."
	# stop and disable existing service
    systemctl disable --now mcsm-web

    # delete existing service
    rm -rf "$service_file_web"
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
" >"$service_file_web"
	
	# Add user section if using mcsm user
	if [[ "$USER" == *"mcsm"* ]]; then
		# Check if the 'User=mcsm' line already exists in the service file
		if grep -q "^User=mcsm$" "$service_file_web"; then
			echo "The service file is configured already."
		else
			# Add 'User=mcsm' to the service file
			sed -i '/^\[Service\]$/a User=mcsm' "$service_file_web"
		fi
	fi
	# Reload Systemd Service
	systemctl daemon-reload
	systemctl enable --now mcsm-web
}

# MCSM Web Update & Installation
Install_Web_Wrapper() {
	web_path="${mcsmanager_install_path}/${mcsm_web}"
	web_data="${web_path}/data"
	web_data_tmp="${mcsmanager_install_path}/web_data_${current_date}"
	if [ -d "$web_path" ]; then
		Echo_Cyan "[+] Updating MCSManager Web..."
		# The backup should be created already, moving the DATA dir to /opt/mcsmanager/web_data should be fast and safe.
		# Use web_data, do not use data as in rare circumstance user may run both update at the same time.
		# Use mv command, this won't create issue in case of an incomplete previous installation (e.g. empty mcsm dir)
		mv "$web_data" "$web_data_tmp"
		# Remove the old web dir
		rm -rf "$web_path"
		
	else
		Echo_Cyan "[+] Install MCSManager Web..."
	fi
    
	
	# Install MCSM Web
	Install_MCSM_Web_Base
	
	# Install MCSM Web Service
	Install_Web_Systemd
}

# MCSM Daemon Base Installation
# Assuming a fresh install (i.e. no file(s) from previous installation) and downloaded source
Install_MCSM_Daemon_Base() {
	# Move downloaded path
	mv "${mcsm_down_temp}/${mcsm_daemon}" "$daemon_path" ||
	# Move helper file(s)
	mv "${mcsm_down_temp}/start-daemon.sh" "${mcsmanager_install_path}/start-daemon.sh"

	# Move back the data directory only if existed
	if [ -d "$daemon_data_tmp" ]; then
		rm -rf "$daemon_data"
		mv "${daemon_data_tmp}" "${daemon_data}"
	fi
	# Dependencies install
	cd "${daemon_path}" || Red_Error "[x] Failed to enter ${daemon_path}"
	# Install dependencies
    Echo_Cyan "[+] Install MCSManager-Daemon dependencies..."
    env "$node_install_path"/bin/node "$node_install_path"/bin/npm install --production --no-fund --no-audit &>/dev/null || Red_Error "[x] Failed to npm install in ${daemon_path}"
	# Return to general dir
	cd "$mcsmanager_install_path"
	# Configure ownership if needed
	if [[ "$USER" == *"mcsm"* ]]; then
		# Change file permission to mcsm user
		chown -R mcsm:mcsm "$daemon_path"
	else
		# Change file permission to root user
		chown -R root:root "$daemon_path"
	fi
	chmod -R 755 "$daemon_path"
}

# MCSM Daemon Service Installation
Install_Daemon_Systemd() {
	Echo_Cyan "[+] Creating MCSManager Daemon service..."
	# stop and disable existing service
    systemctl disable --now mcsm-daemon

    # delete existing service
    rm -rf "$service_file_daemon"
    systemctl daemon-reload

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
" >"$service_file_daemon"
	
	# Add user section if using mcsm user
	if [[ "$USER" == *"mcsm"* ]]; then
		# Check if the 'User=mcsm' line already exists in the service file
		if grep -q "^User=mcsm$" "$service_file_daemon"; then
			echo "The service file is configured already."
		else
			# Add 'User=mcsm' to the service file
			sed -i '/^\[Service\]$/a User=mcsm' "$service_file_daemon"
		fi
	fi
	# Reload Systemd Service
	systemctl daemon-reload
	systemctl enable --now mcsm-daemon
}
# MCSM Web Update & Installation
Install_Daemon_Wrapper() {
	daemon_path="${mcsmanager_install_path}/${mcsm_daemon}"
	daemon_data="${daemon_path}/data"
	daemon_data_tmp="${mcsmanager_install_path}/daemon_data_${current_date}"
	if [ -d "$daemon_path" ]; then
		Echo_Cyan "[+] Updating MCSManager Daemon..."
		# The backup should be created already, moving the DATA dir to /opt/mcsmanager/daemon_data should be fast and safe.
		# Use daemon_data, do not use data as in rare circumstance user may run both update at the same time.
		# Use mv command, this won't create issue in case of an incomplete previous installation (e.g. empty mcsm dir) 
		mv "$daemon_data" "$daemon_data_tmp"
		# Remove the old daemon dir
		rm -rf "$daemon_path"
		
	else
		Echo_Cyan "[+] Install MCSManager daemon..."
	fi
    	
	# Install MCSM Web
	Install_MCSM_Daemon_Base
	
	# Install MCSM Web Service
	Install_Daemon_Systemd
}
# Arguments parsing
Parse_Arguments() {
	while getopts "u:c:" opt; do
		case ${opt} in
			u )
				if [[ "${OPTARG}" == "mcsm" || "${OPTARG}" == "root" ]]; then
					USER="${OPTARG}"
				else
					echo "Invalid user specified."
					Usage
				fi
				;;
			c )
				if [[ "${OPTARG}" == "web" || "${OPTARG}" == "daemon" || "${OPTARG}" == "all" ]]; then
					COMMAND="${OPTARG}"
				else
					echo "Invalid command specified."
					Usage
				fi
				;;
			\? )
				Usage
				;;
			: )
				echo "Option -$OPTARG requires an argument."
				Usage
				;;
		esac
	done
}

# Wrapper for installation
Install_Update() {
	case "$COMMAND" in
    all)
        Install_Web_Wrapper
		Install_Daemon_Wrapper
        ;;

    web)
        Install_Web_Wrapper
        ;;

    daemon)
        Install_Daemon_Wrapper
        ;;

    *)
        echo "Unknown command: $COMMAND, this should not happen in general :( Please report this bug."
        # Exit with an error if COMMAND is unrecognized
        exit 1
        ;;
	esac
}
# Finalize installation
Finalize() {
	#Clear screen
	clear
    #printf "\n\n\n\n"
	echo "______  _______________________  ___"
	echo "___   |/  /_  ____/_  ___/__   |/  /_____ _____________ _______ _____________"
	echo "__  /|_/ /_  /    _____ \__  /|_/ /_  __ \`/_  __ \  __ \`/_  __ \`/  _ \_  ___/"
	echo "_  /  / / / /___  ____/ /_  /  / / / /_/ /_  / / / /_/ /_  /_/ //  __/  /"
	echo "/_/  /_/  \____/  /____/ /_/  /_/  \__,_/ /_/ /_/\__,_/ _\__, / \___//_/"
	echo "                                                        /____/"
	
	case "$COMMAND" in
    all)
            Echo_Yellow "=================================================================="
			Echo_Green "Installation is complete! Welcome to the MCSManager V10!!!"
			Echo_Yellow " "
			Echo_Cyan_N "HTTP Web Service:        "
			Echo_Yellow "http://<Your IP>:23333  (Browser)"
			Echo_Cyan_N "Daemon Address:          "
			Echo_Yellow "ws://<Your IP>:24444    (Cluster)"
			Echo_Red "You must expose ports 23333 and 24444 to use the service properly on the Internet."
			Echo_Yellow " "
			Echo_Cyan "Usage:"
			Echo_Cyan "systemctl start mcsm-{daemon,web}.service"
			Echo_Cyan "systemctl stop mcsm-{daemon,web}.service"
			Echo_Cyan "systemctl restart mcsm-{daemon,web}.service"
			Echo_Yellow " "
			Echo_Green "Official Document: https://docs.mcsmanager.com/"
			Echo_Yellow "=================================================================="
        ;;

    web)
            Echo_Yellow "=================================================================="
			Echo_Green "Installation is complete! Welcome to the MCSManager V10!!!"
			Echo_Yellow " "
			Echo_Cyan_N "HTTP Web Service:        "
			Echo_Yellow "http://<Your IP>:23333  (Browser)"
			Echo_Red "You must expose port 23333 to use the service properly on the Internet."
			Echo_Yellow " "
			Echo_Cyan "Usage:"
			Echo_Cyan "systemctl start mcsm-web.service"
			Echo_Cyan "systemctl stop mcsm-web.service"
			Echo_Cyan "systemctl restart mcsm-web.service"
			Echo_Yellow " "
			Echo_Green "Official Document: https://docs.mcsmanager.com/"
			Echo_Yellow "=================================================================="
        ;;

    daemon)
            Echo_Yellow "=================================================================="
			Echo_Green "Installation is complete! Welcome to the MCSManager V10!!!"
			Echo_Yellow " "
			Echo_Cyan_N "Daemon Address:          "
			Echo_Yellow "ws://<Your IP>:24444    (Cluster)"
			Echo_Red "You must expose port 24444 to use the service properly on the Internet."
			Echo_Yellow " "
			Echo_Cyan "Usage:"
			Echo_Cyan "systemctl start mcsm-daemon.service"
			Echo_Cyan "systemctl stop mcsm-daemon.service"
			Echo_Cyan "systemctl restart mcsm-daemon.service"
			Echo_Yellow " "
			Echo_Green "Official Document: https://docs.mcsmanager.com/"
			Echo_Yellow "=================================================================="
        ;;

    *)
        echo "Unknown command: $COMMAND, this should not happen in general :( Please report this bug."
        # Exit with an error if COMMAND is unrecognized
        exit 1
        ;;
	esac
	# Check if backup_path is not empty
	if [[ -n "$backup_path" ]]; then
		Echo_Green "Your MCSM has been updated from a previous installation. "
		Echo_Green "A complete backup was created at:"
		Echo_Yellow "$backup_path"
		Echo_Green "You can manually delete the backup using command: "
		Echo_Red "rm ${backup_path}"
	fi
	# Move quickstart.md
	mv "${mcsm_down_temp}/quick-start.md" "${mcsmanager_install_path}/quick-start.md"
	# Remove the temp folder
	rm -rf "${mcsm_down_temp}"

	
}
########### Main Logic ################
Main() {
	# Do not create mcsmanager path yet as it will break the logic detecting existing installation
	Initialize "$@"
	# Check if the mcsmanager_install_path exists
	if [ -d "$mcsmanager_install_path" ]; then
		# Backup first, due to potential large file being archived, backup is disabled.
		# Backup_MCSM
		# Install Node.js, this is to ensure the version is up to date.
		Install_Node
		
	else
		# Create mcsmanager path if not already
		mkdir -p "$mcsmanager_install_path"
		# Install Node.js, this is to ensure the version is up to date.
		Install_Node
	fi

	# Install Services based on command
	Install_Update

	# Print helping Information
	Finalize

	Echo_Green "Installation/Upgrading Complete!"
}

Main "$@"