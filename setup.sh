#!/bin/bash
# Official MCSManager installation script.
# This script installs or updates the MCSManager Web and/or Daemon to the latest version.
# ------------------------------------------------------------------------------
# Supported Linux distributions:
# This script supports the following mainstream Linux distributions:
# - Ubuntu: 18.04, 20.04, 22.04, 24.04
# - Debian: 10, 11, 12, 13
# - CentOS: 7, 8 Stream, 9 Stream, 10 Stream
# - RHEL:   7, 8, 9, 10
# - Arch Linux: Support planned (TBD)
# ------------------------------------------------------------------------------

# Target installation directory (can be overridden with --install-dir)
install_dir="/opt/mcsmanager"

# Primary download URL bas. Full package URL = download_base_url + package_name
download_base_url="https://github.com/MCSManager/MCSManager/releases/latest/download/"

# Fallback download URL (can also be a local directory or mirror)
download_fallback_url="https://github.com/MCSManager/MCSManager/releases/latest/download/"

# Name of the release package to download/detect
package_name="mcsmanager_linux_release.tar.gz"

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use \"sudo bash\" instead."
  exit 1
fi

# Required system commands for installation
# These will be checked before logic process
required_commands=(
  chmod
  chown
  wget
  tar
  stat
  useradd
  usermod
  date
)

# Node.js related sections
# Enable strict version checking (exact match)
# enabled -> strict requriement for defined node version
# false -> newer version allowed
# Older version is NEVER allowed
strict_node_version_check=false

# Will be set based on actual node status
install_node=true
# Remove leading "v" from defined version
required_node_ver="${node_version#v}"

# Holds absolute path for node & npm
node_bin_path=""
npm_bin_path=""
# Hold Node.js arch name, e.g. x86_64 -> x64
node_arch=""
# Hold Node.js intallation path, e.g. ${node_install_dir}/node-${node_version}-linux-${arch}
node_path=""

# For installation result
daemon_key=""
daemon_port=""
web_port=""
daemon_key_config_subpath="data/Config/global.json"
web_port_config_subpath="data/SystemConfig/config.json"

# Terminal color & style related
# Default to false, auto check later
SUPPORTS_COLOR=false
SUPPORTS_STYLE=false
# Declare ANSI reset
RESET="\033[0m"

# Foreground colors
declare -A FG_COLORS=(
  [black]="\033[0;30m"
  [red]="\033[0;31m"
  [green]="\033[0;32m"
  [yellow]="\033[0;33m"
  [blue]="\033[0;34m"
  [magenta]="\033[0;35m"
  [cyan]="\033[0;36m"
  [white]="\033[0;37m"
)

# Font styles
declare -A STYLES=(
  [bold]="\033[1m"
  [underline]="\033[4m"
  [italic]="\033[3m"  # Often ignored
  [clear_line]="\r\033[2K"
  [strikethrough]="\033[9m"
)


### Helper Functions
# Execution wrapper, avoid unexpected crashes.
safe_run() {
  local func="$1"
  local err_msg="$2"
  shift 2

  if ! "$func" "$@"; then
    echo "Error: $err_msg"
    exit 1
  fi
}

# Function to ensure the script is run as root
check_root() {
  # Using Bash's built-in EUID variable
  if [ -n "$EUID" ]; then
    if [ "$EUID" -ne 0 ]; then
      cprint red "Error: This script must be run as root. Please use sudo or switch to the root user."
      exit 1
    fi
  else
    # Fallback to using id -u if EUID is unavailable (e.g., non-Bash shell or misconfigured environment)
    if [ "$(id -u)" -ne 0 ]; then
      cprint red "Error: This script must be run as root. Please use sudo or switch to the root user."
      exit 1
    fi
  fi
}

# Function to check whether current terminal support color & style
detect_terminal_capabilities() {
  SUPPORTS_COLOR=false
  SUPPORTS_STYLE=false

  if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    if [ "$(tput colors)" -ge 8 ]; then
      SUPPORTS_COLOR=true
    fi
    if tput bold >/dev/null 2>&1 && tput smul >/dev/null 2>&1; then
      SUPPORTS_STYLE=true
    fi
  fi

  if [ "$SUPPORTS_COLOR" = true ]; then
    cprint green "[OK] Terminal supports colored output."
  else
    cprint yellow "Note: Terminal does not support colored output. Continuing without formatting."
  fi

  if [ "$SUPPORTS_STYLE" = true ]; then
    cprint green "[OK] Terminal supports bold and underline formatting."
  else
    cprint yellow "Note: Terminal does not support advanced text styles."
  fi
}

# Check whether daemon or web is installed
is_component_installed() {
  local component_name="$1"
  local component_path="${install_dir}/${component_name}"

  if [[ -d "$component_path" ]]; then
    cprint green "Component '$component_name' is already installed at $component_path"

    # Set corresponding global variable
    if [[ "$component_name" == "daemon" ]]; then
      daemon_installed=true
    elif [[ "$component_name" == "web" ]]; then
      web_installed=true
    fi

    return 0
  else
    cprint yellow "Component '$component_name' is not installed"

    # Set corresponding global variable
    if [[ "$component_name" == "daemon" ]]; then
      daemon_installed=false
    elif [[ "$component_name" == "web" ]]; then
      web_installed=false
    fi

    return 1
  fi
}

check_component_permission() {
  local component="$1"
  local service_file="${systemd_file}${component}.service"

  if [[ ! -f "$service_file" ]]; then
    cprint yellow "Service file not found: $service_file"
    return 0  # nothing changed
  fi

  # Extract the User= line if it exists
  local user_line
  user_line=$(grep -E '^User=' "$service_file" 2>/dev/null | head -1)

  local user
  if [[ -z "$user_line" ]]; then
    user="root"  # default if no User= is defined
  else
    user="${user_line#User=}"
  fi

  # Validate user
  if [[ "$user" != "root" && "$user" != "mcsm" ]]; then
    cprint red bold "Unsupported user '$user' in $service_file. Expected 'root' or 'mcsm'."
    exit 1
  fi

  # Assign to appropriate global
  if [[ "$component" == "web" ]]; then
    web_installed_user="$user"
  elif [[ "$component" == "daemon" ]]; then
    daemon_installed_user="$user"
  fi

  cprint cyan "Detected $component installed as user: $user"
  return 0
}



parse_args() {
  local explicit_install_flag=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-dir)
        if [[ -n "$2" ]]; then
          install_dir="$2"
          shift 2
        else
          echo "Error: --install-dir requires a path argument."
          exit 1
        fi
        ;;
      --node-install-dir)
        if [[ -n "$2" ]]; then
          node_install_dir="$2"
          shift 2
        else
          echo "Error: --node-install-dir requires a path argument."
          exit 1
        fi
        ;;
      --install)
        explicit_install_flag=true
        if [[ -n "$2" && "$2" != --* ]]; then
          case "$2" in
            daemon)
              install_daemon=true
			  is_component_installed "daemon"
              install_web=false
              check_component_permission "daemon"
              ;;
            web)
              install_daemon=false
			  is_component_installed "web"
              install_web=true
              check_component_permission "web"
              ;;
            all)
              install_daemon=true
              install_web=true
			  is_component_installed "daemon"
			  is_component_installed "web"
              check_component_permission "daemon"
              check_component_permission "web"
              ;;
            *)
              echo "Error: Invalid value for --install. Expected 'daemon', 'web', or 'all'."
              echo "Usage: --install daemon|web|all"
              exit 1
              ;;
          esac
          shift 2
        else
          echo "Error: --install flag provided but no value. Please specify: daemon, web, or all."
          echo "Usage: --install daemon|web|all"
          exit 1
        fi
        ;;
      --user)
        if [[ -n "$2" ]]; then
          case "$2" in
            root)
              install_user="root"
              ;;
            mcsm)
              install_user="mcsm"
              ;;
            *)
              echo "Error: Invalid user '$2'. Only 'root' and 'mcsm' are supported."
              echo "Usage: --user root|mcsm"
              exit 1
              ;;
          esac
          shift 2
        else
          echo "Error: --user requires a value (root or mcsm)."
          exit 1
        fi
        ;;
      --install-source)
        if [[ -n "$2" ]]; then
          install_source_path="$2"
          shift 2
        else
          echo "Error: --install-source requires a file path."
          exit 1
        fi
        ;;
      *)
        echo "Error: Unknown argument: $1"
        exit 1
        ;;
    esac
  done

  # Auto-detect branch: only run if --install was not explicitly passed
  if [[ "$explicit_install_flag" == false ]]; then
    daemon_installed=false
    web_installed=false

    if is_component_installed "daemon"; then
      daemon_installed=true
      check_component_permission "daemon"
    fi
    if is_component_installed "web"; then
      web_installed=true
      check_component_permission "web"
    fi

	# When only one component installed, we wanted to process that one only.
    if [[ "$daemon_installed" == true && "$web_installed" == false ]]; then
      install_daemon=true
      install_web=false
    elif [[ "$daemon_installed" == false && "$web_installed" == true ]]; then
      install_daemon=false
      install_web=true
    else
      install_daemon=true
      install_web=true
    fi
  fi
}


# Get Distribution & Architecture Info
detect_os_info() {
  distro="Unknown"
  version="Unknown"
  arch=$(uname -m)

  # Try primary source
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro_id="${ID,,}"
    version_id="${VERSION_ID,,}"

    case "$distro_id" in
      ubuntu)
        distro="Ubuntu"
        version="$version_id"
        ;;
      debian)
        distro="Debian"
        version="$version_id"
        ;;
      centos)
        distro="CentOS"
        version="$version_id"
        ;;
      rhel*)
        distro="RHEL"
        version="$version_id"
        ;;
      arch)
        distro="Arch"
        version="rolling"
        ;;
      *)
        distro="${ID:-Unknown}"
        version="$version_id"
        ;;
    esac
  fi

  # Fallbacks for missing or invalid version
  if [[ -z "$version" || "$version" == "unknown" || "$version" == "" ]]; then
    if [ -f /etc/issue ]; then
      version_guess=$(grep -oP '[0-9]+(\.[0-9]+)*' /etc/issue | head -1)
      if [[ -n "$version_guess" ]]; then
        version="$version_guess"
      fi
    fi
  fi

  # Normalize version: keep only major version
  version_full="$version"
  if [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    version="${version%%.*}"
  else
    echo "Warning: Could not detect a clean numeric version. Defaulting to unknown."
    version="unknown"
  fi

  cprint cyan "Detected OS: $distro $version_full"
  cprint cyan "Detected Architecture: $arch"
}


# Check if current OS is supported
check_supported_os() {
  local supported_versions="${supported_os[$distro]}"

  if [[ -z "$supported_versions" ]]; then
    echo "Error: Distribution '$distro' is not supported by this installer."
    return 1
  fi

  if [[ "$supported_versions" != *"$version"* ]]; then
    echo "Error: Version '$version' of '$distro' is not supported."
    echo "Supported versions are: $supported_versions"
    return 1
  fi

  cprint green "OS compatibility check passed."
  return 0
}

# Print with specified color and style, fallback to RESET if not supported.
# Supported colors*: black|red|green|yellow|blue|magenta|cyan|white
# Supported styles*: bold|underline|italic|clear_line|strikethrough
# *Note: some style may not necessarily work on all terminals.
# Example usage:
#  cprint green bold "Installation completed successfully."
#  cprint red underline "Failed to detect required command: wget"
#  cprint yellow "Warning: Disk space is low."
#  cprint underline "Failed to detect required command: wget"
#  cprint bold green underline"Installation completed successfully."

cprint() {
  local color=""
  local text=""
  local styles=""
  local disable_prefix=false
  local disable_newline=false

  while [[ $# -gt 1 ]]; do
    case "$1" in
      black|red|green|yellow|blue|magenta|cyan|white)
        color="$1"
        ;;
      bold|underline|italic|clear_line|strikethrough)
        styles+="${STYLES[$1]}"
        ;;
      noprefix)
        disable_prefix=true
        ;;
      nonl)
        disable_newline=true
        ;;
    esac
    shift
  done

  text="$1"

  local prefix_text=""
  if [[ "$disable_prefix" != true ]]; then
    local timestamp="[$(date +%H:%M:%S)]"
    local label="[MCSM Installer]"
    prefix_text="${FG_COLORS[white]}$timestamp $label${RESET} "
  fi

  local prefix=""
  if [[ -n "$color" && "$SUPPORTS_COLOR" = true ]]; then
    prefix+="${FG_COLORS[$color]}"
  fi
  if [[ "$SUPPORTS_STYLE" = true || "$styles" == *"${STYLES[clear_line]}"* ]]; then
    prefix="$styles$prefix"
  fi

  if [[ "$disable_newline" == true ]]; then
    printf "%b%b%s%b" "$prefix_text" "$prefix" "$text" "$RESET"
  else
    printf "%b%b%s%b\n" "$prefix_text" "$prefix" "$text" "$RESET"
  fi
}




# Permission check before proceed with installation
permission_barrier() {
  if [[ "$web_installed" == false && "$daemon_installed" == false ]]; then
    cprint cyan "No components currently installed - skipping permission check."
    return 0
  fi

  for component in web daemon; do
    local is_installed_var="${component}_installed"
    local installed_user_var="${component}_installed_user"

    if [[ "${!is_installed_var}" == true ]]; then
      local installed_user="${!installed_user_var}"

      # Step 0: Ensure installed user is detected
      if [[ -z "$installed_user" ]]; then
        cprint red bold "Detected that '$component' is installed but could not determine the user from its systemd service file."
        cprint red "This may indicate a custom or unsupported service file setup."
        cprint red "Refusing to proceed to avoid potential conflicts."
        exit 1
      fi

      # Step 1: User match check
      if [[ "$installed_user" != "$install_user" ]]; then
        cprint red bold "Permission mismatch for '$component':"
        cprint red "Installed as user: $installed_user"
        cprint red "Current install target user: $install_user"
        cprint red "Unable to proceed due to ownership conflict."
        exit 1
      fi
    fi
  done

  # Step 2: Directory ownership check
  local dir_owner
  dir_owner=$(stat -c '%U' "$install_dir" 2>/dev/null)

  if [[ -z "$dir_owner" ]]; then
    cprint red bold "Unable to determine owner of install_dir: $install_dir"
    exit 1
  fi

  if [[ "$dir_owner" != "$install_user" ]]; then
    cprint red bold "Install directory ownership mismatch:"
    cprint red "  Directory: $install_dir"
    cprint red "  Owned by:  $dir_owner"
    cprint red "  Expected:  $install_user"
    exit 1
  fi

  cprint green bold "Permissions and ownership validated. Proceeding."
  return 0
}



# Map OS arch with actual Node.js Arch name
# This function should be placed after var arch has been assigned a valid value.
resolve_node_arch() {
  case "$arch" in
    x86_64)
      node_arch="x64"
      ;;
    aarch64)
      node_arch="arm64"
      ;;
    armv7l)
      node_arch="armv7l"
      ;;
    *)
      cprint red bold "Unsupported architecture for Node.js: $arch"
      return 1
      ;;
  esac

  # Assign node_path based on resolved arch and current version/install dir
  node_path="${node_install_dir}/node-${node_version}-linux-${node_arch}"

  cprint cyan "Resolved Node.js architecture: $node_arch"
  cprint cyan "Computed Node.js install path: $node_path"
}

# Check if Node.js at PATH is valid.
# This function check Node.js version + NPM (if Node.js valid)
verify_node_at_path() {
  local node_path="$1"
  # Assign value to vlobal variables when verifying
  node_bin_path="$node_path/bin/node"
  npm_bin_path="$node_path/bin/npm"

  # Node binary missing
  if [ ! -x "$node_bin_path" ]; then
    return 1
  fi

  local installed_ver
  installed_ver="$("$node_bin_path" -v 2>/dev/null | sed 's/^v//')"

  # Node exists but version not returned
  if [[ -z "$installed_ver" ]]; then
    return 1
  fi

  # Version mismatch, even if newer
  if [ "$strict_node_version_check" = true ]; then
    if [[ "$installed_ver" != "$required_node_ver" ]]; then
      return 3
    fi
  else
    # Version mismatch, too old.
    local cmp
    cmp=$(printf "%s\n%s\n" "$required_node_ver" "$installed_ver" | sort -V | head -1)
    if [[ "$cmp" != "$required_node_ver" ]]; then
      return 2
    fi
  fi

  # node cmd valid, but npm is missing or broken.
  if [ ! -x "$npm_bin_path" ] || ! "$npm_bin_path" --version >/dev/null 2>&1; then
    return 4
  fi

  return 0
}

# Node.js pre-check. check if we need to install Node.js before installer run.
# Use postcheck_node_after_install() to check after install.
check_node_installed() {
  verify_node_at_path "$node_path"
  local result=$?

  case $result in
    0)
      cprint green bold "Node.js and npm found at $node_path (version $required_node_ver or compatible)"
      install_node=false
      ;;
    1)
      cprint yellow bold "Node.js binary not found or unusable at $node_path"
      install_node=true
      ;;
    2)
      cprint red bold "Node.js version at $node_path is too old. Required: >= $required_node_ver"
      install_node=true
      ;;
    3)
      cprint red bold "Node.js version mismatch. Required: $required_node_ver, found something else."
      install_node=true
      ;;
    4)
      cprint red bold "Node.js is present but npm is missing or broken."
      install_node=true
      ;;
    *)
      cprint red bold "Unexpected error in node verification."
      install_node=true
      ;;
  esac
}

# Node.js post-check. check if Node.js is valid after install.
postcheck_node_after_install() {
  verify_node_at_path "$node_path"
  if [[ $? -ne 0 ]]; then
    cprint red bold "Node.js installation failed or is invalid at $node_path"
    return 1
  else
    cprint green bold "Node.js is installed and functioning at $node_path"
    return 0
  fi
}

# Install Node.js and check
install_node() {
  local archive_name="node-${node_version}-linux-${node_arch}.tar.xz"
  local target_dir="${node_install_dir}/node-${node_version}-linux-${node_arch}"
  local archive_path="${node_install_dir}/${archive_name}"
  local download_url="${node_download_url_base}${node_version}/${archive_name}"
  local fallback="$node_download_fallback"

  cprint cyan bold "Installing Node.js $node_version for arch: $node_arch"

  mkdir -p "$node_install_dir" || {
    cprint red bold "Failed to create node install directory: $node_install_dir"
    return 1
  }

  # Download
  cprint cyan "Downloading Node.js from: $download_url"
  if ! wget --progress=bar:force -O "$archive_path" "$download_url"; then
    cprint yellow "Primary download failed. Attempting fallback..."

    if [[ -n "$fallback" ]]; then
      if [[ "$fallback" =~ ^https?:// ]]; then
        cprint cyan "Downloading from fallback URL: $fallback"
        if ! wget --progress=bar:force -O "$archive_path" "$fallback"; then
          cprint red bold "Fallback download failed from: $fallback"
          return 1
        fi
      elif [ -f "$fallback" ]; then
        cprint cyan "Copying from local fallback: $fallback"
        cp "$fallback" "$archive_path" || {
          cprint red bold "Failed to copy fallback Node.js archive from $fallback"
          return 1
        }
      else
        cprint red bold "Invalid fallback path: $fallback"
        return 1
      fi
    else
      cprint red bold "No fallback source configured. Cannot proceed."
      return 1
    fi
  fi

  # Extract archive
  cprint cyan "Extracting Node.js archive..."
  if ! tar -xf "$archive_path" -C "$node_install_dir"; then
    cprint red bold "Failed to extract Node.js archive."
    return 1
  fi

  chmod -R a+rx "$target_dir" || {
    cprint red bold "Failed to set execute permissions on Node.js files."
    return 1
  }

  verify_node_at_path "$target_dir"
  local result=$?
  if [[ $result -ne 0 ]]; then
    cprint red bold "Node.js installation failed verification."
    return 1
  fi

  cprint cyan "Cleaning up archive..."
  rm -f "$archive_path"

  cprint green bold "Node.js $node_version installed successfully at $target_dir"
  # Save resolved binary paths to global variables
  node_bin_path="${target_dir}/bin/node"
  npm_bin_path="${target_dir}/bin/npm"

  cprint green "Node.js binary: $node_bin_path"
  cprint green "npm binary:     $npm_bin_path"
  return 0
}

# Function to download MCSM package. fetch from primary URL first, then fallback URL.
# This function only put extracted file(s) into install_dir, it does not perform the actual update.
download_mcsm() {
  local archive_name="$package_name"
  local archive_path="${tmp_dir}/${archive_name}"
  local primary_url="${download_base_url}${archive_name}"
  local fallback="$download_fallback_url"

  cprint cyan bold "Downloading MCSManager package..."

  # Step 1: Try downloading from primary URL
  if ! wget --progress=bar:force -O "$archive_path" "$primary_url"; then
    cprint yellow "Primary download failed. Attempting fallback source..."

    if [[ -z "$fallback" ]]; then
      cprint red bold "No fallback URL or path specified."
      return 1
    fi

    if [[ "$fallback" =~ ^https?:// ]]; then
      if ! wget --progress=bar:force -O "$archive_path" "$fallback"; then
        cprint red bold "Fallback download failed from $fallback"
        return 1
      fi
    elif [[ -f "$fallback" ]]; then
      cp "$fallback" "$archive_path" || {
        cprint red bold "Failed to copy fallback archive from $fallback"
        return 1
      }
    else
      cprint red bold "Fallback path is invalid: $fallback"
      return 1
    fi
  fi

  # Step 2: Generate extract directory
  local suffix
  suffix=$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)
  local extracted_tmp_path="${tmp_dir}/mcsm_${suffix}"

  if [[ -e "$extracted_tmp_path" ]]; then
    cprint red bold "Temporary extract path already exists: $extracted_tmp_path"
    return 1
  fi

  mkdir -p "$extracted_tmp_path" || {
    cprint red bold "Failed to create temporary extract directory: $extracted_tmp_path"
    return 1
  }

  cprint cyan "Extracting archive to $extracted_tmp_path..."
  if ! tar -xzf "$archive_path" -C "$extracted_tmp_path"; then
    cprint red bold "Failed to extract archive."
    rm -rf "$extracted_tmp_path"
    return 1
  fi

  rm -f "$archive_path"

  # Step 3: Move the entire extracted directory to install_dir
  install_tmp_dir="${install_dir}/mcsm_${suffix}"

  if [[ -e "$install_tmp_dir" ]]; then
    cprint red bold "Install target already exists at $install_tmp_dir"
    cprint red "  Please remove or rename it before proceeding."
    return 1
  fi

  mv "$extracted_tmp_path" "$install_tmp_dir" || {
    cprint red bold "Failed to move extracted files to $install_tmp_dir"
    return 1
  }

  cprint green bold "MCSManager source extracted and moved to: $install_tmp_dir"
  return 0
}

# Prepare user if needed
prepare_user() {
  if [[ "$install_user" == "root" ]]; then
    cprint cyan "install_user is 'root' - skipping user creation."
    return 0
  fi

  # Check if user already exists
  if id "$install_user" &>/dev/null; then
    cprint green "User '$install_user' already exists."
  else
    cprint cyan "Creating system user: $install_user (nologin, no password)..."
    if ! useradd --system --home "$install_dir" --shell /usr/sbin/nologin "$install_user"; then
      cprint red bold "Failed to create user: $install_user"
      exit 1
    fi
    cprint green "User '$install_user' created."
  fi

  # Docker integration
  if command -v docker &>/dev/null; then
    cprint cyan "Docker is installed - checking group assignment..."

    if getent group docker &>/dev/null; then
      if id -nG "$install_user" | grep -qw docker; then
        cprint green "User '$install_user' is already in the 'docker' group."
      else
        cprint cyan "Adding user '$install_user' to 'docker' group..."
        if usermod -aG docker "$install_user"; then
          cprint green "Docker group access granted to '$install_user'."
        else
          cprint red "Failed to add '$install_user' to 'docker' group. Docker may not be usable by this user."
        fi
      fi
    else
      cprint red "Docker installed but 'docker' group not found. Skipping group assignment."
    fi
  else
    cprint yellow "Docker not installed - skipping Docker group configuration."
  fi

  return 0
}

# Prepare file & permissions before install.
mcsm_install_prepare() {
  # Prepare the user first
  prepare_user
  
  if [[ ! -d "$install_tmp_dir" ]]; then
    cprint red bold "install_tmp_dir does not exist: $install_tmp_dir"
    exit 1
  fi

  cprint cyan "Changing ownership of $install_tmp_dir to user '$install_user'..."
  chown -R "$install_user":"$install_user" "$install_tmp_dir" || {
    cprint red bold "Failed to change ownership of $install_tmp_dir"
	cleanup_install_tmp
    exit 1
  }

  # Normalize install_dir to ensure it ends with a slash
  [[ "${install_dir}" != */ ]] && install_dir="${install_dir}/"

  if [[ "$web_installed" == false && "$daemon_installed" == false ]]; then
    cprint cyan "No existing components detected - skipping data backup/cleanup."
    return 0
  fi

  for component in web daemon; do
    local is_installed_var="${component}_installed"
    if [[ "${!is_installed_var}" == true ]]; then
      local component_path="${install_dir}${component}"
      local data_dir="${component_path}/data"
      local backup_path="${install_dir}${backup_prefix}${component}"

      if [[ ! -d "$component_path" ]]; then
        cprint yellow "Expected installed component directory not found: $component_path"
        continue
      fi

      if [[ -d "$data_dir" ]]; then
        if [[ -e "$backup_path" ]]; then
          cprint red bold "Backup destination already exists: $backup_path"
          cprint red "Please resolve this conflict manually before continuing."
		  cleanup_install_tmp
          exit 1
        fi

        cprint cyan "Backing up data directory for $component..."
        mv "$data_dir" "$backup_path" || {
          cprint red bold "Failed to move $data_dir to $backup_path"
		  cleanup_install_tmp
          exit 1
        }
        cprint green "Moved $data_dir → $backup_path"
      else
        cprint yellow "No data directory found for $component - skipping backup."
      fi

      cprint cyan "Removing old component directory: $component_path"
      rm -rf "$component_path" || {
        cprint red bold "Failed to remove old component directory: $component_path"
		cleanup_install_tmp
        exit 1
      }
    fi
  done

  cprint green bold "Existing components prepared successfully."
  return 0
}

# Install or update a component
install_component() {
  local component="$1"
  local target_path="${install_dir}${component}"
  local backup_data_path="${install_dir}${backup_prefix}${component}"
  local source_path="${install_tmp_dir}/mcsmanager/${component}"

  cprint cyan bold "Installing/Updating component: $component"

  # Step 1: Move new component to install_dir
  if [[ ! -d "$source_path" ]]; then
    cprint red bold "Source directory not found: $source_path"
	cleanup_install_tmp
    exit 1
  fi

  if [[ -e "$target_path" ]]; then
    cprint red bold "Target path already exists: $target_path"
    cprint red "  This should not happen - possible permission error or unclean install."
	cleanup_install_tmp
    exit 1
  fi

  mv "$source_path" "$target_path" || {
    cprint red bold "Failed to move $source_path → $target_path"
	cleanup_install_tmp
    exit 1
  }

  cprint green "Moved $component to $target_path"

  # Step 2: Restore backed-up data directory if present
  if [[ -d "$backup_data_path" ]]; then
    local target_data_path="${target_path}/data"

    cprint cyan "Restoring backed-up data directory for $component..."

    rm -rf "$target_data_path"  # Ensure no conflict
    mv "$backup_data_path" "$target_data_path" || {
      cprint red bold "Failed to restore data directory to $target_data_path"
	  cleanup_install_tmp
      exit 1
    }

    cprint green "Data directory restored: $target_data_path"
  else
    cprint yellow "No backed-up data directory found for $component - fresh install assumed."
  fi

  # Step 3: Install NPM dependencies
  if [[ ! -x "$npm_bin_path" ]]; then
    cprint red bold "npm binary not found or not executable: $npm_bin_path"
	cleanup_install_tmp
    exit 1
  fi

  cprint cyan "Installing dependencies for $component using npm..."
  pushd "$target_path" >/dev/null || {
    cprint red bold "Failed to change directory to $target_path"
	cleanup_install_tmp
    exit 1
  }

  if ! "$npm_bin_path" install --no-audit --no-fund --loglevel=warn; then
    cprint red bold "NPM dependency installation failed for $component"
    popd >/dev/null
	cleanup_install_tmp
    exit 1
  fi

  popd >/dev/null
  cprint green bold "Component '$component' installed/updated successfully."
}

# Create systemd service for a given component.
# This will overwrite the existing service file.
create_systemd_service() {
  local component="$1"
  local service_path="${systemd_file}${component}.service"
  local working_dir="${install_dir}${component}"
  local exec="${node_bin_path} app.js"

  if [[ ! -d "$working_dir" ]]; then
    cprint red bold "Component directory not found: $working_dir"
	cleanup_install_tmp
    return 1
  fi

  cprint cyan "Creating systemd service for '$component'..."

  cat > "$service_path" <<EOF
[Unit]
Description=MCSManager-${component^}
After=network.target

[Service]
Type=simple
WorkingDirectory=${working_dir}
ExecStart=${exec}
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID
Restart=on-failure
User=${install_user}
Environment="PATH=${PATH}"
Environment="NODE_ENV=production"

[Install]
WantedBy=multi-user.target
EOF

  if [[ $? -ne 0 ]]; then
    cprint red bold "Failed to write service file: $service_path"
	cleanup_install_tmp
    return 1
  fi

  chmod 644 "$service_path"
  cprint green "Created systemd unit: $service_path"
  return 0
}

# Extract daemon key and/or http port
extract_component_info() {
  # DAEMON SECTION
  if [[ "$install_daemon" == true ]]; then
    local daemon_service="mcsm-daemon.service"
    local daemon_path="${install_dir}/daemon"
    local daemon_config_path="${daemon_path}/${daemon_key_config_subpath}"

    cprint cyan bold "Starting daemon service..."
    if systemctl start "$daemon_service"; then
      cprint green "Daemon service started."

      sleep 1  # Allow service to init and write configs

      if [[ -f "$daemon_config_path" ]]; then
        daemon_key=$(grep -oP '"key"\s*:\s*"\K[^"]+' "$daemon_config_path")
        daemon_port=$(grep -oP '"port"\s*:\s*\K[0-9]+' "$daemon_config_path")

        if [[ -n "$daemon_key" ]]; then
          cprint green "Extracted daemon key: $daemon_key"
        else
          cprint red "Failed to extract daemon key from: $daemon_config_path"
        fi

        if [[ -n "$daemon_port" ]]; then
          cprint green "Extracted daemon port: $daemon_port"
        else
          cprint red "Failed to extract daemon port from: $daemon_config_path"
        fi
      else
        cprint red "Daemon config file not found: $daemon_config_path"
      fi
    else
      cprint red bold "Failed to start daemon service: $daemon_service"
    fi
  fi

  # WEB SECTION
  if [[ "$install_web" == true ]]; then
    local web_service="mcsm-web.service"
    local web_path="${install_dir}/web"
    local web_config_path="${web_path}/${web_port_config_subpath}"

    cprint cyan bold "Starting web service..."
    if systemctl start "$web_service"; then
      cprint green "Web service started."

      sleep 1  # Allow time to populate config

      if [[ -f "$web_config_path" ]]; then
        web_port=$(grep -oP '"httpPort"\s*:\s*\K[0-9]+' "$web_config_path")
        if [[ -n "$web_port" ]]; then
          cprint green "Extracted web port: $web_port"
        else
          cprint red "Failed to extract web port from: $web_config_path"
        fi
      else
        cprint red "Web config file not found: $web_config_path"
      fi
    else
      cprint red bold "Failed to start web service: $web_service"
    fi
  fi
}

cleanup_install_tmp() {
  if [[ -n "$install_tmp_dir" && -d "$install_tmp_dir" ]]; then
    if rm -rf "$install_tmp_dir"; then
      cprint green "Cleaned up temporary install folder: $install_tmp_dir"
    else
      cprint red "Failed to remove temporary folder: $install_tmp_dir"
    fi
  fi
}

print_install_result() {
  # Clear the screen
  clear || true

  # Print ASCII banner
  cprint white noprefix "______  _______________________  ___"
  cprint white noprefix "___   |/  /_  ____/_  ___/__   |/  /_____ _____________ _______ _____________"
  cprint white noprefix "__  /|_/ /_  /    _____ \__  /|_/ /_  __ \`/_  __ \  __ \`/_  __ \`/  _ \_  ___/"
  cprint white noprefix "_  /  / / / /___  ____/ /_  /  / / / /_/ /_  / / / /_/ /_  /_/ //  __/  /"
  cprint white noprefix "/_/  /_/  \____/  /____/ /_/  /_/  \__,_/ /_/ /_/\__,_/ _\__, / \___//_/"
  echo ""   
  # status summary
  cprint yellow noprefix "Installed/Updated Components:"
  if [[ "$install_daemon" == true && -n "$daemon_key" && -n "$daemon_port" ]]; then
    cprint white noprefix "Daemon"
  elif [[ "$install_daemon" == true ]]; then
    cprint white noprefix nonl "Daemon "
	cprint yellow noprefix "(partial, config not fully detected)"
  fi

  if [[ "$install_web" == true && -n "$web_port" ]]; then
    cprint white noprefix "Web"
  elif [[ "$install_web" == true ]]; then
    cprint white noprefix nonl "Web "
	cprint yellow noprefix "(partial, config not fully detected)"
  fi

  echo ""

  # Local IP detection
  local ip_address
  ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
  [[ -z "$ip_address" ]] && ip_address="YOUR-IP"

  # Daemon info
  if [[ "$install_daemon" == true ]]; then
    local daemon_address="ws://$ip_address:${daemon_port:-Failed to Retrieve from Config file}"
    local daemon_key_display="${daemon_key:-Failed to Retrieve from Config file}"

    cprint yellow noprefix "Daemon Address:"
    cprint white noprefix "  $daemon_address"
    cprint yellow noprefix "Daemon Key:"
    cprint white noprefix "  $daemon_key_display"
    echo ""
  fi

  # Web info
  if [[ "$install_web" == true ]]; then
    local web_address="http://$ip_address:${web_port:-Failed to Retrieve from Config file}"
    cprint yellow noprefix "HTTP Web Interface:"
    cprint white noprefix nonl "  $web_address  "
    cprint yellow noprefix "(open in browser)"
    echo ""
  fi

  # Port guidance
  cprint yellow noprefix "NOTE:"
  cprint white noprefix "  Make sure to expose the above ports through your firewall."
  cprint white noprefix "  If accessing from outside your network, you may need to configure port forwarding on your router."
  echo ""

  # Service management help
  cprint yellow noprefix "Service Management Commands:"
  if [[ "$install_daemon" == true ]]; then
    cprint white noprefix nonl "  systemctl start   "
	cprint yellow noprefix "mcsm-daemon.service"
    cprint white noprefix nonl "  systemctl stop    "
    cprint yellow noprefix "mcsm-daemon.service"
    cprint white noprefix nonl "  systemctl restart "
    cprint yellow noprefix "mcsm-daemon.service"
    cprint white noprefix nonl "  systemctl status  "
    cprint yellow noprefix "mcsm-daemon.service"
  fi
  if [[ "$install_web" == true ]]; then
    cprint white noprefix nonl "  systemctl start   "
	cprint yellow noprefix "mcsm-web.service"
    cprint white noprefix nonl "  systemctl stop    "
    cprint yellow noprefix "mcsm-web.service"
    cprint white noprefix nonl "  systemctl restart "
    cprint yellow noprefix "mcsm-web.service"
    cprint white noprefix nonl "  systemctl status  "
    cprint yellow noprefix "mcsm-web.service"
  fi
  echo ""

  # Official doc
  cprint yellow noprefix  "Official Documentation:"
  cprint white noprefix "  https://docs.mcsmanager.com/"
  echo ""

  # HTTPS support
  cprint yellow noprefix  "Need HTTPS?"
  cprint white noprefix "  To enable secure HTTPS access, configure a reverse proxy:"
  cprint white noprefix "  https://docs.mcsmanager.com/ops/proxy_https.html"
  echo ""

  # Closing message
  cprint green noprefix  "Installation completed. Enjoy managing your servers with MCSManager!"
  echo ""
}

install_mcsm() {
  local components=()

  if [[ "$install_web" == true ]]; then
    install_component "web"
    create_systemd_service "web"
    components+=("web")
  fi

  if [[ "$install_daemon" == true ]]; then
    install_component "daemon"
    create_systemd_service "daemon"
    components+=("daemon")
  fi

  # Reload systemd after any service file changes
  if (( ${#components[@]} > 0 )); then
    cprint cyan "Reloading systemd daemon..."
    # systemctl daemon-reexec
    systemctl daemon-reload

    for comp in "${components[@]}"; do
      local svc="mcsm-${comp}.service"

      cprint cyan "Enabling service: $svc"
      if systemctl enable "$svc" &>/dev/null; then
        cprint green "Enabled service: $svc"
      else
        cprint red bold "Failed to enable service: $svc"
		cleanup_install_tmp
        exit 1
      fi
    done
  fi
  
  # Clean tmp dir
  cleanup_install_tmp
  # Extract installed component info
  safe_run extract_component_info "Failed to extract runtime info from installed services"
  safe_run print_install_result "Failed to print installation result"
  
}

main() {
  trap 'echo "Unexpected error occurred."; exit 99' ERR
  safe_run detect_terminal_capabilities "Failed to detect terminal capabilities"
  safe_run check_root "Script must be run as root"
  safe_run parse_args "Failed to parse arguments" "$@"
  safe_run detect_os_info "Failed to detect OS"
  safe_run check_supported_os "Unsupported OS or version"
  # To be moved to a master pre check function.
  safe_run resolve_node_arch "Failed to resolve Node.js architecture"
  
  safe_run check_required_commands "Missing required system commands"
  
  safe_run check_node_installed "Failed to detect Node.js or npm at expected path. Node.js will be installed."
  if [ "$install_node" = true ]; then
    safe_run install_node "Node.js installation failed"
  fi
  
  safe_run permission_barrier "Permission validation failed - aborting install"
  
  safe_run download_mcsm "Failed to acquire MCSManager source"
  safe_run mcsm_install_prepare "Error while preparing for installation"
  
  safe_run install_mcsm "Failed to install MCSManager"
}

main "$@"
# End of file
