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
install_dir="/opt/mcsmanager/"

# Primary download URL bas. Full package URL = download_base_url + package_name
download_base_url="https://github.com/MCSManager/MCSManager/releases/latest/download/"

# Fallback download URL (can also be a local directory or mirror)
download_fallback_url="https://github.com/MCSManager/MCSManager/releases/latest/download/"

# Name of the release package to download/detect
package_name="mcsmanager_linux_release.tar.gz"

# Node.js version to be installed
node_version="v20.12.2"

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

# Optional: Override the default installation source file.
# If --install-source is specified, the installer will use the provided
# "mcsmanager_linux_release.tar.gz" file instead of downloading it.
# Only support local absolute path.
install_source_path=""

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
)

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
  [italic]="\033[3m"  # Often ignored on many terminals
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
              install_web=false
              ;;
            web)
              install_daemon=false
              install_web=true
              ;;
            all)
              install_daemon=true
              install_web=true
              ;;
            *)
              echo "Error: Invalid value for --install. Expected 'daemon', 'web', or 'all'."
              echo "Usage: --install daemon|web|all"
              exit 1
              ;;
          esac
          shift 2
        else
          echo "Error: --install requires an argument (daemon, web, or all)."
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
cprint() {
  local color=""
  local style=""
  local text=""
  
  # Iterate through all args except last
  while [[ $# -gt 1 ]]; do
    case "$1" in
      black|red|green|yellow|blue|magenta|cyan|white)
        color="$1"
        ;;
      bold|underline|italic)
        style="$1"
        ;;
      *)
        echo "Unknown style or color: $1" >&2
        ;;
    esac
    shift
  done

  text="$1"

  local prefix=""
  if [ "$SUPPORTS_COLOR" = true ] && [[ -n "${FG_COLORS[$color]}" ]]; then
    prefix+="${FG_COLORS[$color]}"
  fi
  if [ "$SUPPORTS_STYLE" = true ] && [[ -n "${STYLES[$style]}" ]]; then
    prefix+="${STYLES[$style]}"
  fi

  printf "%b%s%b\n" "$prefix" "$text" "$RESET"
}











main() {
  trap 'echo "Unexpected error occurred."; exit 99' ERR

  safe_run check_root "Script must be run as root"
  safe_run parse_args "Failed to parse arguments" "$@"
  safe_run detect_os_info "Failed to detect OS"
  safe_run check_supported_os "Unsupported OS or version"
  safe_run check_required_commands "Missing required system commands"
  safe_run detect_terminal_capabilities "Failed to detect terminal capabilities"
  
}
main "$@"