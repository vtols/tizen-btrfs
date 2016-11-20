#/bin/bash

WD=/opt/usr/home/owner
cd $WD
SERVER=$(cat debug-server.txt)
sleep 10
./messages.py $SERVER echo "waiting for CANCEL"
./messages.py $SERVER wait "CANCEL"
./messages.py $SERVER echo "got CANCEL"
systemctl disable startup.service
systemctl reboot
