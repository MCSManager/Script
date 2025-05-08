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


