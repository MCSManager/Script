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

# Node.js version to be installed
# Keep the leading "v"
node_version="v20.12.2"

# Node download base URL - primary
node_download_url_base="https://nodejs.org/dist/"

# Node download URL - fallback.
# This is the URL points directly to the file, not the base. This can also be a local absolute path.
# Only supports https:// or http:// for web locations.
node_download_fallback=""

# Node.js installation path (defaults to the MCSManager installation path. Can be overridden with --node-install-dir)
node_install_dir="$install_dir"

# --------------- Global Variables ---------------#
#                  DO NOT MODIFY                  #


# Component installation options.
# For fresh installs, both daemon and web components are installed by default.
# For updates, behavior depends on detected existing components.
# Can be overridden with --install daemon/web/all
install_daemon=true
install_web=true

# Install MCSM as (default: root).
# To install as a general user (e.g., "mcsm"), use the --user option: --user mcsm
# To ensure compatibility, only user mcsm is supported.
install_user="root"
# Installed user, for permission check
web_installed=false
daemon_installed=false
web_installed_user=""
daemon_installed_user=""

# Service file locations
# the final dir = systemd_file + {web/daemon} + ".service"
systemd_file="/etc/systemd/system/mcsm-"
# Optional: Override the default installation source file.
# If --install-source is specified, the installer will use the provided
# "mcsmanager_linux_release.tar.gz" file instead of downloading it.
# Only support local absolute path.
install_source_path=""

# temp path for extracted file(s)
install_tmp_dir=""

# System architecture (detected automatically)
arch=""
version=""
distro=""

# Supported OS versions (map-style structure)
# Format: supported_os["distro_name"]="version1 version2 version3 ..."
declare -A supported_os
supported_os["Ubuntu"]="18 20 22 24"
supported_os["Debian"]="10 11 12 13"
supported_os["CentOS"]="7 8 8-stream 9-stream 10-stream"
supported_os["RHEL"]="7 8 9 10"
supported_os["Arch"]="rolling"

# Required system commands for installation
# These will be checked before logic process
required_commands=(
  chmod
  chown
  wget
  tar
  stat
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
      echo "Error: This script must be run as root. Please use sudo or switch to the root user."
      exit 1
    fi
  else
    # Fallback to using id -u if EUID is unavailable (e.g., non-Bash shell or misconfigured environment)
    if [ "$(id -u)" -ne 0 ]; then
      echo "Error: This script must be run as root. Please use sudo or switch to the root user."
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
    echo "[OK] Terminal supports colored output."
  else
    echo "Note: Terminal does not support colored output. Continuing without formatting."
  fi

  if [ "$SUPPORTS_STYLE" = true ]; then
    echo "[OK] Terminal supports bold and underline formatting."
  else
    echo "Note: Terminal does not support advanced text styles."
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



# Parse cmd arguments.
parse_args() {
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
        if [[ -n "$2" ]]; then
          case "$2" in
            daemon)
              install_daemon=true
			  check_component_permission "daemon"
              install_web=false
              ;;
            web)
              install_daemon=false
              install_web=true
			  check_component_permission "web"
              ;;
            all)
              install_daemon=true
			  check_component_permission "daemon"
              install_web=true
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
          # No argument passed with --install, detect based on installed components
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

          if [[ "$daemon_installed" == true && "$web_installed" == false ]]; then
            install_daemon=true
            install_web=false
          elif [[ "$daemon_installed" == false && "$web_installed" == true ]]; then
            install_daemon=false
            install_web=true
          else
            # None or both installed perform fresh install or update both
            install_daemon=true
            install_web=true
          fi

          shift 1
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

  echo "Detected OS: $distro $version_full"
  echo "Detected Architecture: $arch"
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

  echo "OS compatibility check passed."
  return 0
}

# Check if all required commands are available
check_required_commands() {
  local missing=0

  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Error: Required command '$cmd' is not available in PATH."
      missing=1
    fi
  done

  if [ "$missing" -ne 0 ]; then
    echo "One or more required commands are missing. Please install them and try again."
    return 1
  fi

  echo "All required commands are available."
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
  
  while [[ $# -gt 1 ]]; do
    case "$1" in
      black|red|green|yellow|blue|magenta|cyan|white)
        color="$1"
        ;;
      bold|underline|italic|clear_line|strikethrough)
        styles+="${STYLES[$1]}"
        ;;
    esac
    shift
  done

  text="$1"

  local prefix=""
  if [[ -n "$color" && "$SUPPORTS_COLOR" = true ]]; then
    prefix+="${FG_COLORS[$color]}"
  fi
  if [ "$SUPPORTS_STYLE" = true ] || [[ "$styles" == *"${STYLES[clear_line]}"* ]]; then
    prefix="$styles$prefix"
  fi

  printf "%b%s%b\n" "$prefix" "$text" "$RESET"
}

# Permission check before proceed with installation
permission_barrier() {
  if [[ "$web_installed" == false && "$daemon_installed" == false ]]; then
    cprint cyan "No components currently installed — skipping permission check."
    return 0
  fi

  for component in web daemon; do
    local is_installed_var="${component}_installed"
    local installed_user_var="${component}_installed_user"

    if [[ "${!is_installed_var}" == true ]]; then
      local installed_user="${!installed_user_var}"

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
    cprint red bold "✖ Unable to determine owner of install_dir: $install_dir"
    exit 1
  fi

  if [[ "$dir_owner" != "$install_user" ]]; then
    cprint red bold "✖ Install directory ownership mismatch:"
    cprint red "  Directory: $install_dir"
    cprint red "  Owned by:  $dir_owner"
    cprint red "  Expected:  $install_user"
    exit 1
  fi

  cprint green bold "✔ Permissions and ownership validated. Proceeding."
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
  local bin_node="$node_path/bin/node"
  local bin_npm="$node_path/bin/npm"

  # Node binary missing
  if [ ! -x "$bin_node" ]; then
    return 1
  fi

  local installed_ver
  installed_ver="$("$bin_node" -v 2>/dev/null | sed 's/^v//')"

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
  if [ ! -x "$bin_npm" ] || ! "$bin_npm" --version >/dev/null 2>&1; then
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





main() {
  trap 'echo "Unexpected error occurred."; exit 99' ERR

  safe_run check_root "Script must be run as root"
  safe_run parse_args "Failed to parse arguments" "$@"
  safe_run detect_os_info "Failed to detect OS"
  safe_run check_supported_os "Unsupported OS or version"
  # To be moved to a master pre check function.
  safe_run resolve_node_arch "Failed to resolve Node.js architecture"
  
  safe_run check_required_commands "Missing required system commands"
  safe_run detect_terminal_capabilities "Failed to detect terminal capabilities"
  safe_run check_node_installed "Failed to detect Node.js or npm at expected path. Node.js will be installed."
  if [ "$install_node" = true ]; then
    safe_run install_node "Node.js installation failed"
  fi
  
  safe_run permission_barrier "Permission validation failed — aborting install"
}
main "$@"