#!/bin/bash

WD=/opt/usr/home/owner
DELAY=10
WAIT=30
COUNT=$1
DEBUG=1

unit=startup.service
unit_prefix=/etc/systemd/system
unit_path=${unit_prefix}/${unit}

function update_counter() {
    echo $NEW_COUNTER > counter.txt
    if [ $NEW_DOWN_COUNTER -le 0 ]; then
        debug_echo "Disable unit"
        systemctl disable $unit
        rm downcounter.txt $unit_path startup.sh
        chown -R owner:users startup
        make_archive
        exit
    fi
    echo $NEW_DOWN_COUNTER > downcounter.txt
}

function load_counter() {
    COUNTER=$(cat counter.txt)
    DOWN_COUNTER=$(cat downcounter.txt)
    st_dir=startup/${COUNTER}
    rm -rf ${st_dir}
    mkdir -p ${st_dir}
    NEW_COUNTER=$((COUNTER+1))
    NEW_DOWN_COUNTER=$((DOWN_COUNTER-1))
}

function make_archive() {
    pushd startup
    rm startup.tar.xz
    tar cvf startup.tar.xz .
    popd
}

function debug_echo() {
    if [ $DEBUG ]; then
        ./messages.py $SERVER echo "$@"
    fi
}

function debug_tee() {
    if [ $DEBUG ]; then
        ./messages.py $SERVER tee
    else
        cat
    fi
}

function debug_cat() {
    if [ $DEBUG ]; then
        ./messages.py $SERVER cat
    fi
}

function startup_stat() {
    sleep $DELAY
    debug_echo ----------
    debug_echo \#$COUNTER
    debug_echo "Left ${DOWN_COUNTER}"
    while true; do
        systemd-analyze | awk '{print $4,$7,$10}' | \
            sed -e 's/s//g' | debug_tee > $st_dir/startup.txt

        systemd-analyze plot > $st_dir/plot.svg
        if [ ! -f $st_dir/startup.txt ]; then
            debug_echo "Didn't create startup stat. Trying to reboot"
            systemctl reboot
        fi

        if [ -s $st_dir/startup.txt ]; then
            break
        fi
        debug_echo "Boot is not finished yet or error occured."
        sleep 1
    done

    dmesg > $st_dir/dmesg.txt
}

function startup_init() {
    if [ ! -f counter.txt ]; then
        debug_echo "New counter"
        echo 1 > counter.txt
        rm -rf startup
    fi

    debug_echo "New downcounter"
    echo $COUNT > downcounter.txt


    cat <<EOF > $unit_path
# path: /etc/systemd/system/startup.service
# systemctl enable startup.service

[Unit]
Description=Systemd startup analysis
Requires=default.target
#Requires=network-online.target

[Service]
ExecStart=/opt/usr/home/owner/startup.sh

[Install]
WantedBy=default.target
EOF
    debug_echo "Enable unit"
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
        bin_name=${BIN_NAMES[$i]}
        debug_echo "Starting ${app_name}"
        su --command="launch_app ${app_name}" owner | debug_cat
        app_pid=$(ps -C ${bin_name} -o pid=)
        echo "${app_name} ${app_pid}" | debug_tee >> $st_dir/pids.txt
    done
    sleep $WAIT
    ps aux > $st_dir/ps.txt
    debug_echo "Running dlog"
    dlogutil -d *:D | grep prt_ltime | tee $st_dir/dlog_raw.txt | \
        awk '{print $7, $12}' | sed -e 's/]//' | \
        debug_tee > $st_dir/dlog.txt
    debug_echo "Done dlog"
    if [ ! -f ${st_dir}/dlog.txt ] || [ ! -s ${st_dir}/dlog.txt ]; then
        debug_echo "Didn't create dlog stats. Trying to reboot"
        systemctl reboot
    fi
    ls $st_dir | debug_cat
}

function clear_cache() {
    sync; echo 3 > /proc/sys/vm/drop_caches
}

cd $WD
SERVER=$(cat debug-server.txt)

if [ -f downcounter.txt ]; then
    if [ $DEBUG ]; then
        ./wait_cancel.sh &
    fi

    debug_echo "Load counter"
    load_counter
    debug_echo "Startup stat"
    startup_stat
    debug_echo "Apps stat"
    launch_stat
    debug_echo "Update counter"
    update_counter
else
    startup_init
fi
debug_echo "Rebooting"
sync; systemctl reboot
