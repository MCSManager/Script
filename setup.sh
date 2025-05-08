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

# System architecture (detected automatically)
arch=""

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
  # Default values
  distro="Unknown"
  version="Unknown"
  arch=""

  # Detect arch
  arch=$(uname -m)

  # Primary detection using /etc/os-release
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro_id="${ID,,}"
    distro_version="${VERSION_ID,,}"

    case "$distro_id" in
      ubuntu)
        distro="Ubuntu"
        version="$distro_version"
        ;;
      debian)
        distro="Debian"
        if grep -q "testing" /etc/debian_version 2>/dev/null; then
          version="testing"
        else
          version="$(cat /etc/debian_version)"
        fi
        ;;
      centos)
        distro="CentOS"
        version="$distro_version"
        ;;
      rhel*)
        distro="RHEL"
        version="$distro_version"
        ;;
      arch)
        distro="Arch"
        version="rolling"
        ;;
    esac

  # Fallbacks for older/partial systems
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    distro="${DISTRIB_ID:-Ubuntu}"
    version="${DISTRIB_RELEASE:-Unknown}"
  elif [ -f /etc/issue ]; then
    if grep -qi "ubuntu" /etc/issue; then
      distro="Ubuntu"
      version="$(grep -oP '[0-9]{2}\.[0-9]{2}' /etc/issue | head -1)"
    fi
  fi

  echo "Detected OS: $distro $version"
  echo "Detected Architecture: $arch"
}















main() {
  trap 'echo "Unexpected error occurred."; exit 99' ERR

  safe_run check_root "Script must be run as root"
  safe_run parse_args "Failed to parse arguments" "$@"
  safe_run detect_os_info "Failed to detect OS"
}
main "$@"