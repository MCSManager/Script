#!/bin/bash

#Global arguments
mcsmanager_install_path="/opt/mcsmanager"
mcsmanager_donwload_addr="http://oss.duzuii.com/d/MCSManager/MCSManager/MCSManager-v10-linux.tar.gz"
package_name="MCSManager-v10-linux.tar.gz"
node="v20.12.2"
arch=$(uname -m)

# Default systemd user is 'mcsm'
USER="mcsm"
COMMAND="all"

