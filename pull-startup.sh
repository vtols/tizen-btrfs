#!/bin/bash

NAME=${1:-startup}
DIR=/opt/usr/home/owner/startup
FILE=${DIR}/startup.tar.xz

mkdir -vp $NAME

sdb pull $FILE $NAME
pushd $NAME
tar xvf startup.tar.xz
rm startup.tar.xz
popd
