#!/bin/bash
# MCSManager官方安装脚本
# 这个脚本将会把MCSManager服务端和节点服务端更新/安装至最新发布版本
# ------------------------------------------------------------------------------
# 受支持的Linux发行版:
# 此脚本支持以下Linux发行版:
# - Ubuntu: 18.04, 20.04, 22.04, 24.04
# - Debian: 10, 11, 12, 13
# - CentOS: 7, 8 Stream, 9 Stream, 10 Stream
# - RHEL:   7, 8, 9, 10
# - Arch Linux: 计划支持 (TBD)
# ------------------------------------------------------------------------------

# 目标安装目录(可以用--install-dir覆盖)
install_dir="/opt/mcsmanager"

# 主要下载链接,完整URL = download_base_url + package_name
download_base_url="https://cdn.imlazy.ink:233/files/"

# 回退下载URL(也可以是本地目录或镜像)
download_fallback_url="https://github.com/MCSManager/MCSManager/releases/latest/download/mcsmanager_linux_release.tar.gz"

# 要下载/检测的发布包的名称
package_name="mcsmanager_linux_release.tar.gz"

# 要安装的Node.js版本
# 保留前导的 "v"
node_version="v20.12.2"
node_version_centos7="v16.20.2"

# Node基础下载URL - primary
node_download_url_base="https://nodejs.org/dist/"

# Node.js的非官方构建,以获得更多ISA支持
node_unoffical_build_url="https://unofficial-builds.nodejs.org/download/release/"

# Node下载URL -fallback
# 这是直接指向文件的URL,而不是基础,这也可以是局部绝对路径
# 仅支持https://或http://用于web位置
node_download_fallback=""

# Node.js安装路径(默认为MCSManager安装路径,可以使用--node-install-dir覆盖)
node_install_dir="$install_dir"

# 文件提取的临时目录
tmp_dir="/tmp"

# 绕过已安装的用户权限检查,用--force权限覆盖
force_permission=false


# ---------------全局变量---------------#
#               禁止修改              #


# 组件安装选项
# 对于全新安装,默认情况下会安装daemon和web组件
# 对于更新,行为取决于检测到的现有组件
# 可以用--install-daemon/web/all覆盖
install_daemon=true
install_web=true

# 以(默认: root)身份安装mcsm
# 要以普通用户身份安装(例如"mcsm"),请使用--user选项: --user mcsm
# 为确保兼容性,仅支持用户mcsm
install_user="root"
# 已安装用户,用于权限检查
web_installed=false
daemon_installed=false
web_installed_user=""
daemon_installed_user=""

# 服务文件位置
# 最终的dir=系统文件+{web/daemon}+".service"
systemd_file="/etc/systemd/system/mcsm-"
# 可选: 覆盖默认安装源文件
# 如果指定了--install-source,安装程序将使用提供的
# mcsmanager_linux_release.tar.gz文件,而不是下载它
# 仅支持本地绝对路径
install_source_path=""

# 提取文件的临时路径
install_tmp_dir="/opt/mcsmanager/mcsm_abcd"

# 数据目录备份的目录名称
# 例如/opt/mcsmanager/daemon/data->/opt/mcsmanager/data_bak_data
# 仅在更新期间有效
backup_prefix="data_bak_"

# 系统架构(自动检测)
arch=""
version=""
distro=""



# 支持的操作系统版本(映射样式结构)
# 格式: supported_os[发行版名称]=版本1版本2版本3...
declare -A supported_os
supported_os["Ubuntu"]="18 20 22 24"
supported_os["Debian"]="10 11 12 13"
supported_os["CentOS"]="7 8 8-stream 9-stream 10-stream"
supported_os["RHEL"]="7 8 9 10"
supported_os["Arch"]="rolling"

# 安装所需的系统命令
# 这些将在逻辑处理之前进行检查
required_commands=(
  chmod
  chown
  wget
  tar
  xz
  stat
  useradd
  usermod
  date
)

# 与Node.js相关的章节
# 启用严格版本检查(精确匹配)
# enabled->对定义的节点版本严格要求
# false->允许更新版本
# 不允许使用旧版本
strict_node_version_check=true

# 将根据实际node状态进行设置
install_node=true
# 从定义版本中删除前导"v"
required_node_ver="${node_version#v}"

# 保存node和npm的绝对路径
node_bin_path=""
npm_bin_path=""
# 保留Node.js的架构名称,例如x86_64->x64
node_arch=""
# 保留Node.js安装路径,例如${Node_install_dir}/Node-${node_version}-linux-${arch}
node_path=""

# 对于安装结果
daemon_key=""
daemon_port=""
web_port=""
daemon_key_config_subpath="data/Config/global.json"
web_port_config_subpath="data/SystemConfig/config.json"

# 终端颜色和风格相关
# 默认为false,稍后自动检查
SUPPORTS_COLOR=false
SUPPORTS_STYLE=false
# 声明ANSI重置
RESET="\033[0m"

# 前景颜色
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

# 字体样式
declare -A STYLES=(
  [bold]="\033[1m"
  [underline]="\033[4m"
  [italic]="\033[3m"  # 经常被忽视
  [clear_line]="\r\033[2K"
  [strikethrough]="\033[9m"
)


### Helper函数
# 执行包装器,避免意外崩溃
safe_run() {
  local func="$1"
  local err_msg="$2"
  shift 2

  if ! "$func" "$@"; then
    echo "错误: $err_msg"
    exit 1
  fi
}

# 确保脚本以root身份运行的函数
check_root() {
  # 使用Bash内置的EUID变量
  if [ -n "$EUID" ]; then
    if [ "$EUID" -ne 0 ]; then
      cprint red "错误: 此脚本须以 root 或 sudo 模式运行，请切换用户或使用 sudo."
      exit 1
    fi
  else
    # 如果EUID不可用(例如,非Bash shell或配置错误的环境),则回退到使用id-u
    if [ "$(id -u)" -ne 0 ]; then
      cprint red "错误: 此脚本须以 root 或 sudo 模式运行，请切换用户或使用 sudo."
      exit 1
    fi
  fi
}

# 这个功能用于检查当前终端是否支持颜色和样式
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
    cprint green "[OK] 当前终端支持彩色输出."
  else
    cprint yellow "注: 当前终端不支持彩色输出，将以无格式模式继续."
  fi

  if [ "$SUPPORTS_STYLE" = true ]; then
    cprint green "[OK] 当前终端支持粗体和下划线格式."
  else
    cprint yellow "注意: 当前终端不支持高级文本样式."
  fi
}

# 检查是否安装了daemon或web
is_component_installed() {
  local component_name="$1"
  local component_path="${install_dir}/${component_name}"

  if [[ -d "$component_path" ]]; then
    cprint green "组件 '$component_name' 已安装在 $component_path"

    # 设置相应的全局变量
    if [[ "$component_name" == "daemon" ]]; then
      daemon_installed=true
    elif [[ "$component_name" == "web" ]]; then
      web_installed=true
    fi

    return 0
  else
    cprint yellow "组件 '$component_name' 未安装"

    # 设置相应的全局变量
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
    cprint yellow "未找到服务文件: $service_file"
    return 0  # 什么都没有改变
  fi

  # 提取User=行(如果存在)
  local user_line
  user_line=$(grep -E '^User=' "$service_file" 2>/dev/null | head -1)

  local user
  if [[ -z "$user_line" ]]; then
    user="root"  # 如果未定义User=,则默认
  else
    user="${user_line#User=}"
  fi

  # 验证用户
  if [[ "$user" != "root" && "$user" != "mcsm" ]]; then
    cprint red bold "$service_file 中配置了不受支持的用户 '$user'，仅支持 'root' 或 'mcsm'."
    exit 1
  fi

  # 分配给适当的全局
  if [[ "$component" == "web" ]]; then
    web_installed_user="$user"
  elif [[ "$component" == "daemon" ]]; then
    daemon_installed_user="$user"
  fi

  cprint cyan "检测到 $component 的安装用户为 $user "
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
          echo "错误: --install-dir 需要一个路径参数."
          exit 1
        fi
        ;;
      --node-install-dir)
        if [[ -n "$2" ]]; then
          node_install_dir="$2"
          shift 2
        else
          echo "错误: --node-install-dir 需要一个路径参数."
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
              echo "错误: --install 的值无效，应为 daemon、web 或 all。"
              echo "用法: --install daemon|web|all"
              exit 1
              ;;
          esac
          shift 2
        else
          echo "错误: --install 的值无效，应为 daemon、web 或 all。"
          echo "用法: --install daemon|web|all"
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
              echo "错误: 无效用户 '$2'，仅支持 'root' 和 'mcsm'。"
              echo "用法: --user root|mcsm"
              exit 1
              ;;
          esac
          shift 2
        else
          echo "错误: --user 需要一个值 (root 或 mcsm)."
          exit 1
        fi
        ;;
      --install-source)
        if [[ -n "$2" ]]; then
          install_source_path="$2"
          shift 2
        else
          echo "错误: --install-source 需要文件路径."
          exit 1
        fi
        ;;
      --force-permission)
        force_permission=true
        shift
        ;;
      *)
        echo "错误: 未知参数: $1"
        exit 1
        ;;
    esac
  done

  # 自动检测分支: 仅在未显式传递--install时运行
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

	# 当只安装了一个组件时,我们只想处理那个组件
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


# 获取分布和架构信息
detect_os_info() {
  distro="Unknown"
  version="Unknown"
  arch=$(uname -m)

  # 尝试主要的来源
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

  # 回退丢失或无效的版本
  if [[ -z "$version" || "$version" == "unknown" || "$version" == "" ]]; then
    if [ -f /etc/issue ]; then
      version_guess=$(grep -oP '[0-9]+(\.[0-9]+)*' /etc/issue | head -1)
      if [[ -n "$version_guess" ]]; then
        version="$version_guess"
      fi
    fi
  fi

  # 标准化版本: 仅保留主要的版本
  version_full="$version"
  cprint cyan "检测到操作系统: $distro $version_full"
  cprint cyan "检测到架构: $arch"
}

version_specific_rules() {
    # 默认值: 除非规则匹配,否则不执行任何操作

    if [[ "$distro" == "CentOS" && "$version" == "7" ]]; then
        cprint yellow "检测到 CentOS 7，正在切换至兼容的 Node.js 版本..."
        node_version="$node_version_centos7"
        required_node_ver="${node_version#v}"
    fi
}

# 安装解压 Node.js .tar.xz 所需的系统依赖（Debian 上为 xz-utils）
install_system_dependencies() {
  if command -v xz >/dev/null 2>&1; then
    return 0
  fi

  cprint cyan "正在安装缺失的系统依赖: xz..."
  if [[ -x "$(command -v apt-get)" ]]; then
    apt-get update -y && apt-get install -y xz-utils
  elif [[ -x "$(command -v dnf)" ]]; then
    dnf install -y xz
  elif [[ -x "$(command -v yum)" ]]; then
    yum install -y xz
  elif [[ -x "$(command -v pacman)" ]]; then
    pacman -S --noconfirm --needed xz
  elif [[ -x "$(command -v zypper)" ]]; then
    zypper --non-interactive install xz
  else
    cprint yellow "未能检测到软件包管理器，请手动安装 xz（xz-utils）。"
    return 0
  fi
}

# 检查是否所有需要的命令都可用
check_required_commands() {
  local missing=0

  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "错误: 必需的命令 '$cmd' 在 PATH 中不可用."
      missing=1
    fi
  done

  if [ "$missing" -ne 0 ]; then
    echo "缺少一个或多个必需的命令，请安装后再试。"
    return 1
  fi

  cprint green "所有必需的命令均可用。"
  return 0
}

# 使用指定的颜色和样式输出结果,如果不支持,请回退到预设
# 支持的颜色*: black|red|green|yellow|blue|magenta|cyan|white
# 支持的样式*: bold|underline|italic|clear_line|strikethrough
# *注意: 某些样式可能不一定适用于所有终端
# 示例用法:
#  cprint green bold "安装已成功完成"
#  cprint red underline "未能检测到所需的命令: wget"
#  cprint yellow "警告: 磁盘空间不足"
#  cprint underline "未能检测到所需的命令: wget"
#  cprint bold green underline"安装已成功完成"

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




# 继续安装前进行权限检查
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

      # 步骤0: 确保检测到已安装的用户
      if [[ -z "$installed_user" ]]; then
        cprint red bold "检测到 '$component' 已安装,但无法从其systemd服务文件确定用户."
        cprint red "这可能表示自定义或不支持的服务文件设置."
        cprint red "拒绝执行以避免潜在的冲突."
        exit 1
      fi

      # 步骤1: 使用可选的强制覆盖进行用户匹配检查
      if [[ "$installed_user" != "$install_user" ]]; then
        if [[ "$force_permission" == true ]]; then
          cprint yellow bold "权限不匹配 '$component':"
          cprint yellow "以用户身份安装: $installed_user"
          cprint yellow "目标安装用户: $install_user"
          cprint yellow "用户不匹配,但设置了--force-permission继续和更新权限..."
		  sleep 3
		else
          cprint red bold "权限不匹配 '$component':"
          cprint red "以用户身份安装: $installed_user"
          cprint red "目标安装用户: $install_user"
          cprint red "用户不匹配。如需强制覆盖，请添加 --force-permission 参数后重试。"
          exit 1
		fi
      else
        cprint green bold "权限检查已通过: '$installed_user' 匹配目标用户."
      fi

    fi
  done

  # 步骤2: 目录所有权检查
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
      cprint yellow "  --force-permission设置尽管不匹配,但继续."
	  sleep 3
    else
      cprint red bold "安装目录所有权不匹配:"
      cprint red "  目录: $install_dir"
      cprint red "  归:  $dir_owner"
      cprint red "  预期:  $install_user"
    exit 1
    fi
  else
    cprint green bold "安装目录所有权检查通过: '$install_dir' 归 '$install_user' 所有。"
  fi

  cprint green bold "权限和所有权验证通过，继续安装。"
  return 0
}



# 将操作系统架构映射为 Node.js 架构名称
# 此函数应放置在为var-arch分配有效值之后
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
    loongarch64)
      node_arch="loong64"
      # 使用非官方构建版
      node_download_url_base=$node_unoffical_build_url
      ;;
    *)
      cprint red bold "不支持的 Node.js 架构: $arch"
      return 1
      ;;
  esac

  # 根据解析的架构和当前版本/安装目录分配node_path
  node_path="${node_install_dir}/node-${node_version}-linux-${node_arch}"

  cprint cyan "已识别 Node.js 架构: $node_arch "
  cprint cyan "Node.js 安装路径: $node_path"
}

# 检查PATH中的Node.js是否有效
# 此功能检查Node.js版本号+NPM(如果Node.js有效)
verify_node_at_path() {
  local node_path="$1"
  node_bin_path="$node_path/bin/node"
  npm_bin_path="$node_path/bin/npm"

  # Node二进制文件缺失
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

  # 使用node(不是$PATH/npm)检查npm是否存在并工作
  if [ ! -x "$npm_bin_path" ]; then
    return 4
  fi

  # 使用node直接运行npm.js,以防env损坏
  local npm_version
  npm_version="$("$node_bin_path" "$npm_bin_path" --version 2>/dev/null)"
  if [[ -z "$npm_version" ]]; then
    return 4
  fi

  return 0
}


# Node.js预检查,检查我们是否需要在MCSManager安装程序运行之前安装Node.js
# 安装后使用postcheck_node_after_install()进行检查
check_node_installed() {
  verify_node_at_path "$node_path"
  local result=$?

  case $result in
    0)
      cprint green bold "Node.js 和 npm 已在 $node_path (版本 $required_node_ver 或兼容)"
      install_node=false
      ;;
    1)
      cprint yellow bold "未找到 Node.js 二进制文件或无法使用 $node_path"
      install_node=true
      ;;
    2)
      cprint red bold "Node.js 版本 $node_path 过旧，要求: >= $required_node_ver "
      install_node=true
      ;;
    3)
      cprint red bold "Node.js 版本不匹配，要求: $required_node_ver，检测到其他 Node.js 版本。"
      install_node=true
      ;;
    4)
      cprint red bold "Node.js 已安装，但 npm 缺失或损坏。"
      install_node=true
      ;;
    *)
      cprint red bold "Node.js 验证时出现意外错误。"
      install_node=true
      ;;
  esac
}

# Node.js检查,安装后检查Node.js是否有效
postcheck_node_after_install() {
  verify_node_at_path "$node_path"
  if [[ $? -ne 0 ]]; then
    cprint red bold "Node.js 安装失败或路径无效: $node_path"
    return 1
  else
    cprint green bold "Node.js 已在 $node_path 安装并运行"
    return 0
  fi
}

# 安装并检查Node.js
install_node() {
  local archive_name="node-${node_version}-linux-${node_arch}.tar.xz"
  local target_dir="${node_install_dir}/node-${node_version}-linux-${node_arch}"
  local archive_path="${node_install_dir}/${archive_name}"
  local download_url="${node_download_url_base}${node_version}/${archive_name}"
  local fallback="$node_download_fallback"

  cprint cyan bold "正在安装 Node.js $node_version 架构: $node_arch"

  mkdir -p "$node_install_dir" || {
    cprint red bold "创建 Node.js 安装目录失败: $node_install_dir"
    return 1
  }

  # 下载
  cprint cyan "正在下载 Node.js: $download_url"
  if ! wget --progress=bar:force -O "$archive_path" "$download_url"; then
    cprint yellow "尝试从主下载源下载失败，正在尝试备用下载源......"

    if [[ -n "$fallback" ]]; then
      if [[ "$fallback" =~ ^https?:// ]]; then
        cprint cyan "正在从备用 URL 下载: $fallback"
        if ! wget --progress=bar:force -O "$archive_path" "$fallback"; then
          cprint red bold "备用下载失败: $fallback"
          return 1
        fi
      elif [ -f "$fallback" ]; then
        cprint cyan "正在从本地备份复制: $fallback"
        cp "$fallback" "$archive_path" || {
          cprint red bold "复制备用 Node.js 存档失败: $fallback"
          return 1
        }
      else
        cprint red bold "无效的备用路径: $fallback"
        return 1
      fi
    else
      cprint red bold "未配置备用源，无法继续。"
      return 1
    fi
  fi

  # 提取压缩包
  cprint cyan "正在提取 Node.js 存档..."
  if ! tar -xf "$archive_path" -C "$node_install_dir"; then
    cprint red bold "提取 Node.js 文件失败。"
    return 1
  fi

  chmod -R a+rx "$target_dir" || {
    cprint red bold "设置 Node.js 文件执行权限失败。"
    return 1
  }

  verify_node_at_path "$target_dir"
  local result=$?
  if [[ $result -ne 0 ]]; then
    cprint red bold "Node.js 安装验证失败。"
    return 1
  fi

  cprint cyan "正在清理文件..."
  rm -f "$archive_path"

  cprint green bold "Node.js $node_version 安装成功 $target_dir"
  # 将解析的二进制可执行文件路径保存到全局变量
  node_bin_path="${target_dir}/bin/node"
  npm_bin_path="${target_dir}/bin/npm"

  cprint green "Node.js 二进制文件: $node_bin_path"
  cprint green "npm 二进制文件:     $npm_bin_path"
  return 0
}

# 用于下载mcsm软件包的功能,首先从主URL获取,如果主URL不可用,那么从备用URL获取
# 此函数仅将提取的文件放入install_dir中,它不会执行实际的更新
download_mcsm() {
  local archive_name="$package_name"
  local archive_path="${tmp_dir}/${archive_name}"
  local primary_url="${download_base_url}${archive_name}"
  local fallback="$download_fallback_url"

  cprint cyan bold "正在下载 MCSManager 安装包..."

  # 步骤1: 尝试从主URL下载
  if ! wget --progress=bar:force -O "$archive_path" "$primary_url"; then
    cprint yellow "尝试从主下载源下载失败，正在尝试备用下载源..."

    if [[ -z "$fallback" ]]; then
      cprint red bold "未指定备用 URL 或路径。"
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

  # 步骤2: 创建提取目录
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

  # 步骤3: 将整个提取的目录移动到install_dir
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

  cprint green bold "MCSManager 安装文件已解压并移动至: $install_tmp_dir"
  return 0
}

# 必要时为用户做好准备
prepare_user() {
  if [[ "$install_user" == "root" ]]; then
    cprint cyan "安装用户为 root，跳过用户创建。"
    return 0
  fi

  # 检查用户是否已存在
  if id "$install_user" &>/dev/null; then
    cprint green "用户 '$install_user' 已经存在."
  else
    cprint cyan "正在创建系统用户: $install_user (无登录，无密码)..."
    if ! useradd --system --home "$install_dir" --shell /usr/sbin/nologin "$install_user"; then
      cprint red bold "创建用户失败: $install_user"
      exit 1
    fi
    cprint green "用户 '$install_user' 已创建."
  fi
 

  # Docker集成
  if command -v docker &>/dev/null; then
    cprint cyan "检测到 Docker 已安装，正在检查用户组配置..."

    if getent group docker &>/dev/null; then
      if id -nG "$install_user" | grep -qw docker; then
        cprint green "用户 '$install_user' 已经在docker组中."
      else
        cprint cyan "添加用户 '$install_user' 到 'docker' 组..."
        if usermod -aG docker "$install_user"; then
          cprint green "已授予用户 '$install_user' 的 Docker 组访问权限。"
        else
          cprint red "未能将 '$install_user' 添加至 Docker 组，该用户可能无法使用 Docker。"
        fi
      fi
    else
      cprint red "Docker 已安装，但未找到 Docker 组，跳过组配置。"
    fi
  else
    cprint yellow "未检测到 Docker，跳过用户组配置。"
  fi

  return 0
}
# 用于停止mcsm服务(如果存在)的功能
stop_mcsm_services() {
  cprint yellow bold "正在尝试停止 mcsm-web 和 mcsm-daemon 服务..."

  # 尝试停止mcsm面板进程
  cprint blue "正在停止 mcsm-web..."
  if systemctl stop mcsm-web; then
    cprint green "mcsm-web 已停止."
  else
    cprint red bold "警告: 未能停止 mcsm-web（可能不存在或已停止）。"
  fi

  # 尝试停止mcsm守护进程
  cprint blue "正在停止 mcsm-daemon..."
  if systemctl stop mcsm-daemon; then
    cprint green "mcsm-daemon 已停止."
  else
    cprint red bold "警告: 未能停止 mcsm-daemon（可能不存在或已停止）。"
  fi
}
# 安装前准备文件和权限
mcsm_install_prepare() {

  # 停止服务(如果存在)
  stop_mcsm_services
  
  if [[ ! -d "$install_tmp_dir" ]]; then
    cprint red bold "临时安装目录不存在: $install_tmp_dir"
    exit 1
  fi

  cprint cyan "正在将 $install_tmp_dir 的所有权更改为用户 '$install_user'..."
  chown -R "$install_user":"$install_user" "$install_tmp_dir" || {
    cprint red bold "所有权更改失败: $install_tmp_dir"
	cleanup_install_tmp
    exit 1
  }

  # 规范install_dir以确保它以"/"结尾
  [[ "${install_dir}" != */ ]] && install_dir="${install_dir}/"

  if [[ "$web_installed" == false && "$daemon_installed" == false ]]; then
    cprint cyan "未检测到现有组件，跳过数据备份/清理。"
    return 0
  fi

  cprint green bold "现有组件准备完成。"
  return 0
}

# 安装或更新组件
install_component() {
  local component="$1"
  local target_path="${install_dir}${component}"
  local backup_data_path="${install_dir}${backup_prefix}${component}"
  local source_path="${install_tmp_dir}/mcsmanager/${component}"

  cprint cyan bold "正在安装/更新组件: $component"

  # 步骤1:将新组件移动到install_dir
  if [[ ! -d "$source_path" ]]; then
    cprint red bold "找不到源目录: $source_path"
	cleanup_install_tmp
    exit 1
  fi
  
  cprint cyan "正在删除依赖库文件: $target_path/node_modules/"
  if [[ -d "$target_path/node_modules/" ]]; then
    rm -rf "$target_path/node_modules/"
  fi

  if cp -a "$source_path"/. "$target_path"; then
    cprint green "文件已更新: $source_path → $target_path"
    rm -rf "$source_path"
  else
    cprint red bold "文件更新失败: $source_path → $target_path"
    cleanup_install_tmp
    exit 1
  fi
  cprint green "已移动 $component 到 $target_path"


  # 步骤3: 安装NPM依赖库
  if [[ ! -x "$npm_bin_path" ]]; then
    cprint red bold "未找到 npm 二进制文件或无法执行: $npm_bin_path"
	cleanup_install_tmp
    exit 1
  fi

  cprint cyan "正在使用 npm 为 $component 安装依赖..."
  pushd "$target_path" >/dev/null || {
    cprint red bold "切换目录失败: $target_path"
	cleanup_install_tmp
    exit 1
  }


  if ! "$node_bin_path" "$npm_bin_path" install --registry=https://registry.npmmirror.com --no-audit --no-fund --loglevel=warn; then
    cprint red bold "npm 依赖安装失败: $component"
    popd >/dev/null
    cleanup_install_tmp
    exit 1
  fi
   
  popd >/dev/null
  cprint green bold "组件 '$component' 安装/更新成功."
}

# 为给定的组件创建systemd服务
# 这将会覆盖现有的服务文件
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

  cprint cyan "正在创建 systemd 服务: '$component'..."

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
    cprint red bold "无法写入服务文件: $service_path"
	cleanup_install_tmp
    return 1
  fi

  chmod 644 "$service_path"
  cprint green "systemd 单元已创建: $service_path"
  return 0
}

# 提取守护程序密钥和/或http端口
extract_component_info() {
  # 守护进程部分
  if [[ "$install_daemon" == true ]]; then
    local daemon_service="mcsm-daemon.service"
    local daemon_path="${install_dir}/daemon"
    local daemon_config_path="${daemon_path}/${daemon_key_config_subpath}"

    cprint cyan bold "正在启动守护进程服务..."
    if systemctl restart "$daemon_service"; then
      cprint green "守护进程服务已启动."

      sleep 3  # 允许服务初始化和写入配置

      if [[ -f "$daemon_config_path" ]]; then
        daemon_key=$(grep -oP '"key"\s*:\s*"\K[^"]+' "$daemon_config_path")
        daemon_port=$(grep -oP '"port"\s*:\s*\K[0-9]+' "$daemon_config_path")

        if [[ -n "$daemon_key" ]]; then
          cprint green "守护进程密钥已提取: $daemon_key"
        else
          cprint red "守护进程密钥提取失败: $daemon_config_path"
        fi

        if [[ -n "$daemon_port" ]]; then
          cprint green "守护进程端口已提取: $daemon_port"
        else
          cprint red "守护进程端口提取失败: $daemon_config_path"
        fi
      else
        cprint red "未找到守护进程配置文件: $daemon_config_path"
      fi
    else
      cprint red bold "守护进程服务启动失败: $daemon_service"
    fi
  fi

  # 面板端部分
  if [[ "$install_web" == true ]]; then
    local web_service="mcsm-web.service"
    local web_path="${install_dir}/web"
    local web_config_path="${web_path}/${web_port_config_subpath}"

    cprint cyan bold "正在启动面板服务..."
    if systemctl restart "$web_service"; then
      cprint green "面板服务已启动."

      sleep 3  # 留出时间填充配置

      if [[ -f "$web_config_path" ]]; then
        web_port=$(grep -oP '"httpPort"\s*:\s*\K[0-9]+' "$web_config_path")
        if [[ -n "$web_port" ]]; then
          cprint green "面板端口已提取: $web_port"
        else
          cprint red "面板端口提取失败: $web_config_path"
        fi
      else
        cprint red "未找到面板配置文件: $web_config_path"
      fi
    else
      cprint red bold "面板服务启动失败: $web_service"
    fi
  fi
}

cleanup_install_tmp() {
  if [[ -n "$install_tmp_dir" && -d "$install_tmp_dir" ]]; then
    if rm -rf "$install_tmp_dir"; then
      cprint green "临时安装文件夹已清理: $install_tmp_dir"
    else
      cprint red "临时文件夹删除失败: $install_tmp_dir"
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
  # 状态摘要
  cprint yellow noprefix "安装/更新组件:"
  if [[ "$install_daemon" == true && -n "$daemon_key" && -n "$daemon_port" ]]; then
    cprint white noprefix "Daemon"
  elif [[ "$install_daemon" == true ]]; then
    cprint white noprefix nonl "Daemon "
	cprint yellow noprefix "(部分配置未检测到)"
  fi

  if [[ "$install_web" == true && -n "$web_port" ]]; then
    cprint white noprefix "Web"
  elif [[ "$install_web" == true ]]; then
    cprint white noprefix nonl "Web "
	cprint yellow noprefix "(部分配置未检测到)"
  fi

  echo ""

  # 本地IP检测
  local ip_address
  ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
  [[ -z "$ip_address" ]] && ip_address="你的IP地址"

  # Daemon信息
  if [[ "$install_daemon" == true ]]; then
    local daemon_address="ws://$ip_address:${daemon_port:-未能从配置文件中获取}"
    local daemon_key_display="${daemon_key:-未能从配置文件中获取}"

    cprint yellow noprefix "守护进程地址:"
    cprint white noprefix "  $daemon_address"
    cprint yellow noprefix "守护进程密钥:"
    cprint white noprefix "  $daemon_key_display"
    echo ""
  fi

  # Web信息
  if [[ "$install_web" == true ]]; then
    local web_address="http://$ip_address:${web_port:-未能从配置文件中获取}"
    cprint yellow noprefix "HTTP 面板地址:"
    cprint white noprefix nonl "  $web_address  "
    cprint yellow noprefix "(请在你的浏览器中打开)"
    echo ""
  fi

  # 端口号指导
  cprint yellow noprefix "注意:"
  cprint white noprefix "  请确保防火墙已放行上述端口。"
  cprint white noprefix "  如需从外部网络访问，可能需要在路由器上配置端口转发。"
  echo ""

  # 服务管理帮助
  cprint yellow noprefix "MCSManager 管理命令:"
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

  # 官方文档
  cprint yellow noprefix  "官方文档:"
  cprint white noprefix "  https://docs.mcsmanager.com/zh_cn/"
  echo ""

  # HTTPS帮助
  cprint yellow noprefix  "需要 HTTPS?"
  cprint white noprefix "  如需启用 HTTPS 安全访问，请配置反向代理:"
  cprint white noprefix "  https://docs.mcsmanager.com/zh_cn/ops/proxy_https.html"
  echo ""
  
  if [[ "$force_permission" == true ]]; then
    cprint red noprefix "[注意] 您选择了在安装期间覆盖权限。"
    cprint red noprefix "            您可能需要手动运行: chown -R $install_user <path> 以修正权限。"
  fi

  # 结束语
  cprint green noprefix  "安装完成，祝您使用愉快!"
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

  # 在任何服务文件更改后重新加载systemd
  if (( ${#components[@]} > 0 )); then
    cprint cyan "正在重新加载 systemd 守护进程..."
    # systemctl daemon-reexec
    systemctl daemon-reload

    for comp in "${components[@]}"; do
      local svc="mcsm-${comp}.service"

      cprint cyan "正在启用服务: $svc"
      if systemctl enable "$svc" &>/dev/null; then
        cprint green "服务已启用: $svc"
      else
        cprint red bold "服务启用失败: $svc"
		cleanup_install_tmp
        exit 1
      fi
    done
  fi
  
  # 清理临时目录
  cleanup_install_tmp
  # 提取已安装的组件信息
  safe_run extract_component_info "未能从已安装服务中提取运行时信息"
  safe_run print_install_result "未能打印安装结果"
  
}

main() {
  trap 'echo "发生意外错误。"; exit 99' ERR
  safe_run detect_terminal_capabilities "检测终端功能失败"
  safe_run check_root "脚本须以 root 身份运行"
  safe_run parse_args "解析参数失败" "$@"
  safe_run detect_os_info "未能检测当前使用的操作系统"
  safe_run version_specific_rules "应用发行版/版本特定规则失败"
  
  # 移动到master预检查功能
  safe_run resolve_node_arch "解析 Node.js 架构失败"

  safe_run install_system_dependencies "安装系统依赖失败"
  safe_run check_required_commands "缺少必要的系统命令"
  
  safe_run check_node_installed "未在预期目录检测到可用的 Node.js 或 npm，将安装 Node.js。"
  if [ "$install_node" = true ]; then
    safe_run install_node "Node.js 安装失败"
  fi

  safe_run permission_barrier "权限验证失败，中止安装。"

  safe_run prepare_user "用户权限准备失败"
  
  safe_run download_mcsm "获取 MCSManager 安装包失败"
  safe_run mcsm_install_prepare "准备安装时出错"
  
  safe_run install_mcsm "未能安装 MCSManager"
}
main "$@"
