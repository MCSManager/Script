#!/bin/bash
set -e

echo "[-] Checking the operating environment..."

if [ ! -f /opt/node/bin/node ]; then
    echo "[x] The nodejs runtime environment could not be found, you may be using an incomplete version"
    exit 1
fi

if [ -d /opt/daemon ]; then
    type=daemon
elif [ -d /opt/web ]; then 
    type=web
else
    echo "[x] The MCSManager file directory could not be found, you may be using an incomplete version"
    exit 1
fi

echo "[-] The operating environment is normal, starting the MCSManager..."

cd /opt/$type
eval "/opt/node/bin/node /opt/$type/app.js"