#!/bin/bash

WD=/opt/usr/home/owner
cd $WD

unit=bnotify.service
unit_prefix=/etc/systemd/system
unit_path=${unit_prefix}/${unit}

SERVER=$(cat debug-server.txt)

if [ -f bnotify ]; then
    sleep 5
    ./messages.py $SERVER echo "BNOTIFY"
    rm bnotify*
    systemctl disable $unit
else
    ./messages.py $SERVER echo "Install bnotify"
    touch bnotify
    cat <<EOF > $unit_path
# path: /etc/systemd/system/bnotify.service
# systemctl enable bnotify.service

[Unit]
Description=Boot notification

[Service]
ExecStart=/opt/usr/home/owner/bnotify.sh

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable $unit
fi

