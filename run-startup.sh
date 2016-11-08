#!/bin/bash

user_dir=/opt/usr/home/owner
script=startup.sh

sdb push startup.sh $user_dir
sdb shell "cd ${user_dir}; chmod +x ${script}"
sdb root on
sdb shell "cd ${user_dir}; ./${script} $1"
