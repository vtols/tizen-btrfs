#!/bin/bash

WD=/opt/usr/home/owner
DELAY=20
WAIT=50
COUNT=4
if [ $1 ]; then
    COUNT=$1
fi

unit=startup.service
unit_prefix=/etc/systemd/system
unit_path=${unit_prefix}/${unit}

function update_counter() {
    COUNTER=$(cat counter.txt)
    st_dir=startup/${COUNTER}
    rm -rf ${st_dir}
    mkdir -p ${st_dir}
    NEW_COUNTER=$((COUNTER-1))
    echo $NEW_COUNTER > counter.txt
}

function check_counter() {
    if [ $NEW_COUNTER -eq 0 ]; then
        systemctl disable $unit
        rm counter.txt $unit_path startup.sh
        chown -R owner:owner startup
        exit
    fi
}

function startup_stat() {
    sleep $DELAY
    systemd-analyze > $st_dir/startup.txt
}

function startup_init() {
    echo $COUNT > counter.txt

    cat <<EOF > $unit_path
# path: /etc/systemd/system/startup.service
# systemctl enable startup.service

[Unit]
Description=Systemd startup analysis

[Service]
ExecStart=/opt/usr/home/owner/startup.sh

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable $unit
}

LAUNCH_SET=(
    org.example.calculator
    org.example.ddktest
    org.example.glbasicrenderer
    org.example.player
    org.tizen.dpm-toolkit
    org.tizen.chromium-efl.mini_browser
)

function launch_stat() {
    #clear_cache
    num_apps=${#LAUNCH_SET[@]}
    indices=$(seq 0 $(($num_apps-1)))
    for i in $indices;
    do
        app_name=${LAUNCH_SET[$i]}
        su --command="launch_app ${app_name}" owner
        app_pid=$(ps aux | grep ${app_name} | head -n 1 | awk '{print $2}')
        #app_pid=$(ps -C ${app} -o pid=)
        echo "${app_name} ${app_pid}" >> $st_dir/pids.txt
    done
    sleep $WAIT
    dlogutil -d *:D | grep prt_ltime > $st_dir/dlog.txt
}

cd $WD
if [ -f counter.txt ]; then
    update_counter

    startup_stat
    launch_stat

    check_counter
else
    startup_init
fi
sync; systemctl reboot
