#!/bin/bash

WD=/opt/usr/home/owner
DELAY=20
WAIT=30
COUNT=$1

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
        chown -R owner:users startup
        exit
    fi
}

function startup_stat() {
    sleep $DELAY
    systemd-analyze | awk '{print $4,$7,$10}' | \
        sed -e 's/s//g' > $st_dir/startup.txt

    dmesg > $st_dir/dmesg.txt
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

BIN_NAMES=(
    calculator
    ddktest
    glrenderer
    player
    org.tizen.dpm-toolkit
    mini_browser
)

function launch_stat() {
    num_apps=${#LAUNCH_SET[@]}
    indices=$(seq 0 $(($num_apps-1)))
    for i in $indices;
    do
        clear_cache
        app_name=${LAUNCH_SET[$i]}
        su --command="launch_app ${app_name}" owner
        app_pid=$(ps -C ${BIN_NAMES[$i]} -o pid=)
        echo "${app_name} ${app_pid}" >> $st_dir/pids.txt
    done
    sleep $WAIT
    ps aux > $st_dir/ps.txt
    dlogutil -d *:D | grep prt_ltime | tee $st_dir/dlog_raw.txt | \
        awk '{print $7, $12}' | sed -e 's/]//' > $st_dir/dlog.txt
}

function clear_cache() {
    sync; echo 3 > /proc/sys/vm/drop_caches
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
