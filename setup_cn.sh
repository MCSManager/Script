#!/bin/bash
# MCSManager官方安装脚本.
# 这个脚本将会把MCSManager服务端和节点服务端更新/安装至最新发布版本.
# ------------------------------------------------------------------------------
# 受支持的Linux:
# 此脚本支持以下Linux发行版:
# - Ubuntu: 18.04, 20.04, 22.04, 24.04
# - Debian: 10, 11, 12, 13
# - CentOS: 7, 8 Stream, 9 Stream, 10 Stream
# - RHEL:   7, 8, 9, 10
# - Arch Linux: Support planned (TBD)
# ------------------------------------------------------------------------------

# Target installation directory (can be overridden with --install-dir)
install_dir="/opt/mcsmanager"

# Primary download URL bas. Full package URL = download_base_url + package_name
download_base_url="https://cdn.imlazy.ink:233/files/"

# Fallback download URL (can also be a local directory or mirror)
download_fallback_url="https://github.com/MCSManager/MCSManager/releases/latest/download/mcsmanager_linux_release.tar.gz"

# Name of the release package to download/detect
package_name="mcsmanager_linux_release.tar.gz"

# Node.js version to be installed
# Keep the leading "v"
node_version="v20.12.2"
node_version_centos7="v16.20.2"

# Node download base URL - primary
node_download_url_base="https://nodejs.org/dist/"

# Node download URL - fallback.
# This is the URL points directly to the file, not the base. This can also be a local absolute path.
# Only supports https:// or http:// for web locations.
node_download_fallback=""

# Node.js installation path (defaults to the MCSManager installation path. Can be overridden with --node-install-dir)
node_install_dir="$install_dir"

# Temp dir for file extraction
tmp_dir="/tmp"

# Bypass installed user permission check, override by --force-permission
force_permission=false


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
install_tmp_dir="/opt/mcsmanager/mcsm_abcd"

# dir name for data dir backup
# e.g. /opt/mcsmanager/daemon/data -> /opt/mcsmanager/data_bak_data
# only valid for when during an update
backup_prefix="data_bak_"

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
  useradd
  usermod
  date
)

# Node.js related sections
# Enable strict version checking (exact match)
# enabled -> strict requriement for defined node version
# false -> newer version allowed
# Older version is NEVER allowed
strict_node_version_check=true

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
      cprint red "错误: 这个脚本只能运行在root或sudo模式下,请尝试切换用户或者使用sudo."
      exit 1
    fi
  else
    # Fallback to using id -u if EUID is unavailable (e.g., non-Bash shell or misconfigured environment)
    if [ "$(id -u)" -ne 0 ]; then
      cprint red "错误: 这个脚本只能运行在root或sudo模式下,请尝试切换用户或者使用sudo."
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
    cprint green "[OK] 这个终端支持彩色输出."
  else
    cprint yellow "注：终端不支持彩色输出。不格式化继续."
  fi

  if [ "$SUPPORTS_STYLE" = true ]; then
    cprint green "[OK] 终端支持粗体和下划线格式."
  else
    cprint yellow "注意：终端不支持高级文本样式."
  fi
}

# Check whether daemon or web is installed
is_component_installed() {
  local component_name="$1"
  local component_path="${install_dir}/${component_name}"

  if [[ -d "$component_path" ]]; then
    cprint green "组件 '$component_name' 已经被安装在 $component_path"

    # Set corresponding global variable
    if [[ "$component_name" == "daemon" ]]; then
      daemon_installed=true
    elif [[ "$component_name" == "web" ]]; then
      web_installed=true
    fi

    return 0
  else
    cprint yellow "组件 '$component_name' 未被安装"

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
    cprint yellow "找不到服务文件: $service_file"
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
    cprint red bold "不支持的用户 '$user' 在 $service_file. 使用 'root' 或 'mcsm'."
    exit 1
  fi

  # Assign to appropriate global
  if [[ "$component" == "web" ]]; then
    web_installed_user="$user"
  elif [[ "$component" == "daemon" ]]; then
    daemon_installed_user="$user"
  fi

  cprint cyan "已删除 $component 以用户身份安装: $user"
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
          echo "错误：--install-dir需要一个路径参数."
          exit 1
        fi
        ;;
      --node-install-dir)
        if [[ -n "$2" ]]; then
          node_install_dir="$2"
          shift 2
        else
          echo "错误：--node-install-dir需要一个路径参数."
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
              echo "错误：--install的值无效。期望‘daemon’， ‘web’或‘all’."
              echo "Usage: --install daemon|web|all"
              exit 1
              ;;
          esac
          shift 2
        else
          echo "错误：提供了--install标志，但没有值。请指定：daemon、web或all."
          echo "使用方法: --install daemon|web|all"
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
              echo "错误:无效用户 '$2'. 只有 'root' 和 'mcsm' 受支持."
              echo "使用方法: --user root|mcsm"
              exit 1
              ;;
          esac
          shift 2
        else
          echo "错误：--user需要一个值 (root 或 mcsm)."
          exit 1
        fi
        ;;
      --install-source)
        if [[ -n "$2" ]]; then
          install_source_path="$2"
          shift 2
        else
          echo "错误：--install-source需要文件路径."
          exit 1
        fi
        ;;
      --force-permission)
        force_permission=true
        shift
        ;;
      *)
        echo "错误：未知参数t: $1"
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
  cprint cyan "检测到操作系统: $distro $version_full"
  cprint cyan "检测到架构: $arch"
}

version_specific_rules() {
    # Default: do nothing unless a rule matches

    if [[ "$distro" == "CentOS" && "$version" == "7" ]]; then
        cprint yellow "Detected CentOS 7 — overriding Node.js version."
        node_version="$node_version_centos7"
        required_node_ver="${node_version#v}"
    fi
}

# Check if all required commands are available
check_required_commands() {
  local missing=0

  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "错误：必需的命令 '$cmd' 在PATH中不可用."
      missing=1
    fi
  done

  if [ "$missing" -ne 0 ]; then
    echo "缺少一个或多个必需的命令。请安装后再试."
    return 1
  fi

  cprint green "所有必需的命令都可用."
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
    cprint cyan "当前没有安装组件-跳过权限检查."
    return 0
  fi

  for component in web daemon; do
    local is_installed_var="${component}_installed"
    local installed_user_var="${component}_installed_user"

    if [[ "${!is_installed_var}" == true ]]; then
      local installed_user="${!installed_user_var}"

      # Step 0: Ensure installed user is detected
      if [[ -z "$installed_user" ]]; then
        cprint red bold "检测到 '$component' 已安装，但无法从其systemd服务文件确定用户."
        cprint red "这可能表示自定义或不支持的服务文件设置."
        cprint red "拒绝执行以避免潜在的冲突."
        exit 1
      fi

      # Step 1: User match check with optional force override
      if [[ "$installed_user" != "$install_user" ]]; then
        if [[ "$force_permission" == true ]]; then
          cprint yellow bold "权限不匹配 '$component':"
          cprint yellow "以用户身份安装: $installed_user"
          cprint yellow "目标安装用户: $install_user"
          cprint yellow "用户不匹配，但设置了--force-permission。继续和更新权限…"
		  sleep 3
		else
          cprint red bold "权限不匹配 '$component':"
          cprint red "以用户身份安装: $installed_user"
          cprint red "目标安装用户: $install_user"
          cprint red "用户不匹配，但设置了--force-permission。继续和更新权限..."
          exit 1
		fi
      else
        cprint green bold "权限检查已通过: '$installed_user' 匹配目标用户."
      fi

    fi
  done

  # Step 2: Directory ownership check
  local dir_owner
  dir_owner=$(stat -c '%U' "$install_dir" 2>/dev/null)

  if [[ -z "$dir_owner" ]]; then
    cprint red bold "无法确定安装目录的所有者: $install_dir"
    exit 1
  fi

  if [[ "$dir_owner" != "$install_user" ]]; then
    if [[ "$force_permission" == true ]]; then
      cprint yellow bold "安装目录所有权不匹配:"
      cprint yellow "  目录: $install_dir"
      cprint yellow "  归:  $dir_owner"
      cprint yellow "  预期:  $install_user"
      cprint yellow "  --force-permission设置。尽管不匹配，但继续."
	  sleep 3
    else
      cprint red bold "安装目录所有权不匹配:"
      cprint red "  目录: $install_dir"
      cprint red "  归:  $dir_owner"
      cprint red "  预期:  $install_user"
    exit 1
    fi
  else
    cprint green bold "安装目录所有权检查通过: '$install_dir' is owned by '$install_user'."
  fi

  cprint green bold "验证了权限和所有权。继续."
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
      cprint red bold "Node.js不支持的架构: $arch"
      return 1
      ;;
  esac

  # Assign node_path based on resolved arch and current version/install dir
  node_path="${node_install_dir}/node-${node_version}-linux-${node_arch}"

  cprint cyan "解析了Node.js架构: $node_arch"
  cprint cyan "Node.js安装路径: $node_path"
}

# Check if Node.js at PATH is valid.
# This function check Node.js version + NPM (if Node.js valid)
verify_node_at_path() {
  local node_path="$1"
  node_bin_path="$node_path/bin/node"
  npm_bin_path="$node_path/bin/npm"

  # Node binary missing
  if [ ! -x "$node_bin_path" ]; then
    return 1
  fi

  local installed_ver
  installed_ver="$("$node_bin_path" -v 2>/dev/null | sed 's/^v//')"

  if [[ -z "$installed_ver" ]]; then
    return 1
  fi

  if [ "$strict_node_version_check" = true ]; then
    if [[ "$installed_ver" != "$required_node_ver" ]]; then
      return 3
    fi
  else
    local cmp
    cmp=$(printf "%s\n%s\n" "$required_node_ver" "$installed_ver" | sort -V | head -1)
    if [[ "$cmp" != "$required_node_ver" ]]; then
      return 2
    fi
  fi

  # Check if npm exists and works using node (not $PATH/npm)
  if [ ! -x "$npm_bin_path" ]; then
    return 4
  fi

  # Use node to run npm.js directly, in case env is broken
  local npm_version
  npm_version="$("$node_bin_path" "$npm_bin_path" --version 2>/dev/null)"
  if [[ -z "$npm_version" ]]; then
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
      cprint green bold "Node.js和npm在 $node_path (版本 $required_node_ver 或兼容)"
      install_node=false
      ;;
    1)
      cprint yellow bold "Node.js二进制文件未找到或无法使用 $node_path"
      install_node=true
      ;;
    2)
      cprint red bold "Node.js版本 $node_path 太老. 要求: >= $required_node_ver"
      install_node=true
      ;;
    3)
      cprint red bold "Node.js版本不匹配。要求: $required_node_ver, 发现了其他的Node.js版本."
      install_node=true
      ;;
    4)
      cprint red bold "Node.js存在，但npm缺失或损坏."
      install_node=true
      ;;
    *)
      cprint red bold "Node验证中出现意外错误."
      install_node=true
      ;;
  esac
}

# Node.js post-check. check if Node.js is valid after install.
postcheck_node_after_install() {
  verify_node_at_path "$node_path"
  if [[ $? -ne 0 ]]; then
    cprint red bold "Node.js安装失败或无效 $node_path"
    return 1
  else
    cprint green bold "Node.js的安装和运行在 $node_path"
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

  cprint cyan bold "安装Node.js $node_version 架构: $node_arch"

  mkdir -p "$node_install_dir" || {
    cprint red bold "创建Node安装目录失败: $node_install_dir"
    return 1
  }

  # Download
  cprint cyan "下载Node.js: $download_url"
  if ! wget --progress=bar:force -O "$archive_path" "$download_url"; then
    cprint yellow "主下载失败。尝试备用下载……"

    if [[ -n "$fallback" ]]; then
      if [[ "$fallback" =~ ^https?:// ]]; then
        cprint cyan "从备用URL下载: $fallback"
        if ! wget --progress=bar:force -O "$archive_path" "$fallback"; then
          cprint red bold "备用下载失败: $fallback"
          return 1
        fi
      elif [ -f "$fallback" ]; then
        cprint cyan "从本地备份进行复制: $fallback"
        cp "$fallback" "$archive_path" || {
          cprint red bold "复制备用Node.js存档失败 $fallback"
          return 1
        }
      else
        cprint red bold "无效的备用路径: $fallback"
        return 1
      fi
    else
      cprint red bold "没有配置备用源。不能继续进行."
      return 1
    fi
  fi

  # Extract archive
  cprint cyan "提取Node.js存档..."
  if ! tar -xf "$archive_path" -C "$node_install_dir"; then
    cprint red bold "提取Node.js文件失败."
    return 1
  fi

  chmod -R a+rx "$target_dir" || {
    cprint red bold "在Node.js文件上设置执行权限失败."
    return 1
  }

  verify_node_at_path "$target_dir"
  local result=$?
  if [[ $result -ne 0 ]]; then
    cprint red bold "Node.js安装验证失败."
    return 1
  fi

  cprint cyan "清理文件……"
  rm -f "$archive_path"

  cprint green bold "Node.js $node_version 安装成功 $target_dir"
  # Save resolved binary paths to global variables
  node_bin_path="${target_dir}/bin/node"
  npm_bin_path="${target_dir}/bin/npm"

  cprint green "Node.js 二进制文件: $node_bin_path"
  cprint green "npm 二进制文件:     $npm_bin_path"
  return 0
}

# Function to download MCSM package. fetch from primary URL first, then fallback URL.
# This function only put extracted file(s) into install_dir, it does not perform the actual update.
download_mcsm() {
  local archive_name="$package_name"
  local archive_path="${tmp_dir}/${archive_name}"
  local primary_url="${download_base_url}${archive_name}"
  local fallback="$download_fallback_url"

  cprint cyan bold "下载MCSManager安装包…"

  # Step 1: Try downloading from primary URL
  if ! wget --progress=bar:force -O "$archive_path" "$primary_url"; then
    cprint yellow "主下载失败。尝试备用资源…"

    if [[ -z "$fallback" ]]; then
      cprint red bold "没有指定备用URL或路径."
      return 1
    fi

    if [[ "$fallback" =~ ^https?:// ]]; then
      if ! wget --progress=bar:force -O "$archive_path" "$fallback"; then
        cprint red bold "备用下载失败 $fallback"
        return 1
      fi
    elif [[ -f "$fallback" ]]; then
      cp "$fallback" "$archive_path" || {
        cprint red bold "未能复制备用文件 $fallback"
        return 1
      }
    else
      cprint red bold "备用路径无效: $fallback"
      return 1
    fi
  fi

  # Step 2: Generate extract directory
  local suffix
  suffix=$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)
  local extracted_tmp_path="${tmp_dir}/mcsm_${suffix}"

  if [[ -e "$extracted_tmp_path" ]]; then
    cprint red bold "临时提取路径已存在: $extracted_tmp_path"
    return 1
  fi

  mkdir -p "$extracted_tmp_path" || {
    cprint red bold "创建临时解压目录失败: $extracted_tmp_path"
    return 1
  }

  cprint cyan "将存档提取到 $extracted_tmp_path..."
  if ! tar -xzf "$archive_path" -C "$extracted_tmp_path"; then
    cprint red bold "提取存档失败."
    rm -rf "$extracted_tmp_path"
    return 1
  fi

  rm -f "$archive_path"

  # Step 3: Move the entire extracted directory to install_dir
  install_tmp_dir="${install_dir}/mcsm_${suffix}"

  if [[ -e "$install_tmp_dir" ]]; then
    cprint red bold "安装目标已经存在 $install_tmp_dir"
    cprint red "  请在继续之前删除或重命名它."
    return 1
  fi

  mv "$extracted_tmp_path" "$install_tmp_dir" || {
    cprint red bold "未能将解压缩的文件移动到 $install_tmp_dir"
    return 1
  }

  cprint green bold "MCSManager源提取并移动到: $install_tmp_dir"
  return 0
}

# Prepare user if needed
prepare_user() {
  if [[ "$install_user" == "root" ]]; then
    cprint cyan "安装用户是'root' -跳过用户创建."
    return 0
  fi

  # Check if user already exists
  if id "$install_user" &>/dev/null; then
    cprint green "用户 '$install_user' 已经存在."
  else
    cprint cyan "创建系统用户: $install_user (无登录，无密码)..."
    if ! useradd --system --home "$install_dir" --shell /usr/sbin/nologin "$install_user"; then
      cprint red bold "创建用户失败: $install_user"
      exit 1
    fi
    cprint green "用户 '$install_user' 已创建."
  fi
 

  # Docker integration
  if command -v docker &>/dev/null; then
    cprint cyan "Docker已被安装 -检查组分配…"

    if getent group docker &>/dev/null; then
      if id -nG "$install_user" | grep -qw docker; then
        cprint green "用户 '$install_user' 已经在“docker”组中."
      else
        cprint cyan "添加用户 '$install_user' 到 'docker' 组..."
        if usermod -aG docker "$install_user"; then
          cprint green "授予的Docker组访问权限 '$install_user'."
        else
          cprint red "未能添加 '$install_user' 给“Docker”组。这个用户可能无法使用Docker."
        fi
      fi
    else
      cprint red "安装了Docker，但没有找到Docker组。跳过组分配."
    fi
  else
    cprint yellow "未安装Docker -跳过Docker组配置."
  fi

  return 0
}
# Function to stop MCSM services if they exist
stop_mcsm_services() {
  cprint yellow bold "试图停止mcsm-web和mcsm-daemon服务..."

  # Attempt to stop mcsm-web
  cprint blue "正在停止 mcsm-web..."
  if systemctl stop mcsm-web; then
    cprint green "mcsm-web 已停止."
  else
    cprint red bold "警告：未能停止mcsm-web（可能不存在或已停止）."
  fi

  # Attempt to stop mcsm-daemon
  cprint blue "正在停止 mcsm-daemon..."
  if systemctl stop mcsm-daemon; then
    cprint green "mcsm-daemon 已停止."
  else
    cprint red bold "警告：未能停止mcsm-daemon（可能不存在或已停止）."
  fi
}
# Prepare file & permissions before install.
mcsm_install_prepare() {

  # Stop service if existed
  stop_mcsm_services
  
  if [[ ! -d "$install_tmp_dir" ]]; then
    cprint red bold "临时安装目录不存在: $install_tmp_dir"
    exit 1
  fi

  cprint cyan "改变所有权 $install_tmp_dir 到用户 '$install_user'..."
  chown -R "$install_user":"$install_user" "$install_tmp_dir" || {
    cprint red bold "所有权变更失败 $install_tmp_dir"
	cleanup_install_tmp
    exit 1
  }

  # Normalize install_dir to ensure it ends with a slash
  [[ "${install_dir}" != */ ]] && install_dir="${install_dir}/"

  if [[ "$web_installed" == false && "$daemon_installed" == false ]]; then
    cprint cyan "没有检测到现有组件-跳过数据备份/清理."
    return 0
  fi

  cprint green bold "已成功准备现有组件."
  return 0
}

# Install or update a component
install_component() {
  local component="$1"
  local target_path="${install_dir}${component}"
  local backup_data_path="${install_dir}${backup_prefix}${component}"
  local source_path="${install_tmp_dir}/mcsmanager/${component}"

  cprint cyan bold "安装/更新组件: $component"

  # Step 1: Move new component to install_dir
  if [[ ! -d "$source_path" ]]; then
    cprint red bold "找不到源目录: $source_path"
	cleanup_install_tmp
    exit 1
  fi
  
  cprint cyan "删除依赖库文件 $target_path/node_modules/"
  if [[ -d "$target_path/node_modules/" ]]; then
    rm -rf "$target_path/node_modules/"
  fi

  if cp -a "$source_path"/. "$target_path"; then
    cprint green "更新的文件 $source_path → $target_path"
    rm -rf "$source_path"
  else
    cprint red bold "更新文件失败 $source_path → $target_path"
    cleanup_install_tmp
    exit 1
  fi
  cprint green "已移动 $component 到 $target_path"


  # Step 3: Install NPM dependencies
  if [[ ! -x "$npm_bin_path" ]]; then
    cprint red bold "找不到npm二进制文件或无法执行: $npm_bin_path"
	cleanup_install_tmp
    exit 1
  fi

  cprint cyan "正在使用npm安装依赖库 $component ..."
  pushd "$target_path" >/dev/null || {
    cprint red bold "更改目录失败 $target_path"
	cleanup_install_tmp
    exit 1
  }


  if ! "$node_bin_path" "$npm_bin_path" install --registry=https://registry.npmmirror.com --no-audit --no-fund --loglevel=warn; then
    cprint red bold "NPM依赖项安装失败 $component"
    popd >/dev/null
    cleanup_install_tmp
    exit 1
  fi
   
  popd >/dev/null
  cprint green bold "组件 '$component' 安装/更新成功."
}

# Create systemd service for a given component.
# This will overwrite the existing service file.
create_systemd_service() {
  local component="$1"
  local service_path="${systemd_file}${component}.service"
  local working_dir="${install_dir}${component}"
  local exec="${node_bin_path} app.js"

  if [[ ! -d "$working_dir" ]]; then
    cprint red bold "找不到组件目录: $working_dir"
	cleanup_install_tmp
    return 1
  fi

  cprint cyan "创建systemd服务 '$component'..."

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
  cprint green "创建的systemd单元: $service_path"
  return 0
}

# Extract daemon key and/or http port
extract_component_info() {
  # DAEMON SECTION
  if [[ "$install_daemon" == true ]]; then
    local daemon_service="mcsm-daemon.service"
    local daemon_path="${install_dir}/daemon"
    local daemon_config_path="${daemon_path}/${daemon_key_config_subpath}"

    cprint cyan bold "启动守护进程服务..."
    if systemctl restart "$daemon_service"; then
      cprint green "守护进程服务已启动."

      sleep 3  # Allow service to init and write configs

      if [[ -f "$daemon_config_path" ]]; then
        daemon_key=$(grep -oP '"key"\s*:\s*"\K[^"]+' "$daemon_config_path")
        daemon_port=$(grep -oP '"port"\s*:\s*\K[0-9]+' "$daemon_config_path")

        if [[ -n "$daemon_key" ]]; then
          cprint green "提取的守护进程密钥: $daemon_key"
        else
          cprint red "提取守护进程密钥失败: $daemon_config_path"
        fi

        if [[ -n "$daemon_port" ]]; then
          cprint green "提取的守护进程端口: $daemon_port"
        else
          cprint red "提取守护进程端口失败: $daemon_config_path"
        fi
      else
        cprint red "没有找到守护进程配置文件: $daemon_config_path"
      fi
    else
      cprint red bold "启动守护进程服务失败: $daemon_service"
    fi
  fi

  # WEB SECTION
  if [[ "$install_web" == true ]]; then
    local web_service="mcsm-web.service"
    local web_path="${install_dir}/web"
    local web_config_path="${web_path}/${web_port_config_subpath}"

    cprint cyan bold "正在启动面板服务..."
    if systemctl restart "$web_service"; then
      cprint green "面板服务已启动."

      sleep 3  # Allow time to populate config

      if [[ -f "$web_config_path" ]]; then
        web_port=$(grep -oP '"httpPort"\s*:\s*\K[0-9]+' "$web_config_path")
        if [[ -n "$web_port" ]]; then
          cprint green "提取的面板端口: $web_port"
        else
          cprint red "提取面板端口失败: $web_config_path"
        fi
      else
        cprint red "面板配置文件未找到： $web_config_path"
      fi
    else
      cprint red bold "启动面板服务失败: $web_service"
    fi
  fi
}

cleanup_install_tmp() {
  if [[ -n "$install_tmp_dir" && -d "$install_tmp_dir" ]]; then
    if rm -rf "$install_tmp_dir"; then
      cprint green "已清理临时安装文件夹: $install_tmp_dir"
    else
      cprint red "删除临时文件夹失败: $install_tmp_dir"
    fi
  fi
}

print_install_result() {
  # 清空屏幕
  clear || true

  # 打印 ASCII 横幅
  cprint white noprefix "______  _______________________  ___"
  cprint white noprefix "___   |/  /_  ____/_  ___/__   |/  /_____ _____________ _______ _____________"
  cprint white noprefix "__  /|_/ /_  /    _____ \__  /|_/ /_  __ \`/_  __ \  __ \`/_  __ \`/  _ \_  ___/"
  cprint white noprefix "_  /  / / / /___  ____/ /_  /  / / / /_/ /_  / / / /_/ /_  /_/ //  __/  /"
  cprint white noprefix "/_/  /_/  \____/  /____/ /_/  /_/  \__,_/ /_/ /_/\__,_/ _\__, / \___//_/"
  echo ""   
  # status summary
  cprint yellow noprefix "安装/更新组件:"
  if [[ "$install_daemon" == true && -n "$daemon_key" && -n "$daemon_port" ]]; then
    cprint white noprefix "Daemon"
  elif [[ "$install_daemon" == true ]]; then
    cprint white noprefix nonl "Daemon "
	cprint yellow noprefix "(部分，未完全检测到配置)"
  fi

  if [[ "$install_web" == true && -n "$web_port" ]]; then
    cprint white noprefix "Web"
  elif [[ "$install_web" == true ]]; then
    cprint white noprefix nonl "Web "
	cprint yellow noprefix "(部分，未完全检测到配置)"
  fi

  echo ""

  # Local IP detection
  local ip_address
  ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
  [[ -z "$ip_address" ]] && ip_address="你的IP"

  # Daemon info
  if [[ "$install_daemon" == true ]]; then
    local daemon_address="ws://$ip_address:${daemon_port:-Failed to Retrieve from Config file}"
    local daemon_key_display="${daemon_key:-Failed to Retrieve from Config file}"

    cprint yellow noprefix "守护进程地址:"
    cprint white noprefix "  $daemon_address"
    cprint yellow noprefix "守护进程秘钥:"
    cprint white noprefix "  $daemon_key_display"
    echo ""
  fi

  # Web info
  if [[ "$install_web" == true ]]; then
    local web_address="http://$ip_address:${web_port:-Failed to Retrieve from Config file}"
    cprint yellow noprefix "HTTP面板地址:"
    cprint white noprefix nonl "  $web_address  "
    cprint yellow noprefix "(在你的浏览器中打开)"
    echo ""
  fi

  # Port guidance
  cprint yellow noprefix "注意:"
  cprint white noprefix "  确保防火墙放行上述端口."
  cprint white noprefix "  如果从外部网络访问，您可能需要在路由器上配置端口转发."
  echo ""

  # Service management help
  cprint yellow noprefix "MCSManager管理命令:"
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
  cprint yellow noprefix  "官方文档:"
  cprint white noprefix "  https://docs.mcsmanager.com/zh_cn/"
  echo ""

  # HTTPS support
  cprint yellow noprefix  "需要HTTPS?"
  cprint white noprefix "  为了开启HTTPS安全访问，需要配置反向代理:"
  cprint white noprefix "  https://docs.mcsmanager.com/zh_cn/ops/proxy_https.html"
  echo ""
  
  if [[ "$force_permission" == true ]]; then
    cprint red noprefix "[重点] 您选择在安装期间重写权限."
    cprint red noprefix "            你可能需要运行: chown -R $install_user <path> 手动更新权限."
  fi

  # Closing message
  cprint green noprefix  "安装完成。享受使用MCSManager管理服务器的乐趣!"
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
    cprint cyan "重新加载systemd守护进程..."
    # systemctl daemon-reexec
    systemctl daemon-reload

    for comp in "${components[@]}"; do
      local svc="mcsm-${comp}.service"

      cprint cyan "启用服务: $svc"
      if systemctl enable "$svc" &>/dev/null; then
        cprint green "已启用服务: $svc"
      else
        cprint red bold "启用服务失败: $svc"
		cleanup_install_tmp
        exit 1
      fi
    done
  fi
  
  # Clean tmp dir
  cleanup_install_tmp
  # Extract installed component info
  safe_run extract_component_info "未能从已安装的服务中提取运行时信息"
  safe_run print_install_result "未能打印安装结果"
  
}

main() {
  trap 'echo "发生意外错误."; exit 99' ERR
  safe_run detect_terminal_capabilities "检测终端功能失败"
  safe_run check_root "脚本必须以root身份运行"
  safe_run parse_args "解析参数失败" "$@"
  safe_run detect_os_info "OS检测失败"
  safe_run version_specific_rules "Failed to apply distro/version specific rules"
  
  # To be moved to a master pre check function.
  safe_run resolve_node_arch "解析Node.js架构失败"
  
  safe_run check_required_commands "缺少必要的系统命令"
  
  safe_run check_node_installed "在预期目录上检测到Node.js或npm失败。Node.js将被安装."
  if [ "$install_node" = true ]; then
    safe_run install_node "Node.js安装失败"
  fi

  safe_run permission_barrier "权限验证失败-中止安装"

  safe_run prepare_user "准备用户权限失败。处理步骤."
  
  safe_run download_mcsm "获取MCSManager源失败。处理步骤"
  safe_run mcsm_install_prepare "准备安装时出错"
  
  safe_run install_mcsm "未能安装 MCSManager"
}
main "$@"
