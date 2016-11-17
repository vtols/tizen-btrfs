#!/bin/bash

NAME=${1:-startup}

mkdir -vp $NAME
sdb pull /opt/usr/home/owner/startup $NAME
