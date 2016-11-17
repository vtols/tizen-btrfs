#!/bin/bash

user_dir=/opt/usr/home/owner
script=startup.sh

sdb push startup.sh $user_dir
sdb push wait_cancel.sh $user_dir
sdb push messages.py $user_dir
sdb shell "cd ${user_dir}; chmod +x ${script}"
sdb root on
sdb shell "cd ${user_dir}; echo $2 > debug-server.txt; ./${script} $1"
