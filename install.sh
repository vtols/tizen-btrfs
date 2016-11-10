#!/bin/bash

DIR=$(pwd)
ARCH_DIRS=$DIR/archives

boot_disk=$1

function message() {
    echo -e "\033[1m${1}\033[0m"
}

function download_archives() {
    if [ ! -d $$ARCH_DIRS ]; then
        mkdir -p $ARCH_DIRS
    fi
    message "Downloading boot, firmware, opengl drivers and Tizen  sample apps..."
    pushd $ARCH_DIRS
    wget -nc -i ../files.urls
    cp *boot-armv7* boot.tar.gz
    cp *wayland* firmware.tar.gz
    cp master.zip apps.zip
    cp opengl-es-mali-t628.tar.gz opengl.tar.gz
    popd
}

function prepare_images {
    message "Repacking images..."
    pushd $ARCH_DIRS
    for algo in no zlib lzo
    do
        ./repack.sh firmware.tar.gz $algo
    done
    popd
}

function fuse_sdcard {
    boot_files=$(cat ${ARCH_DIRS}/files.urls | head -n 2)
    ./sd_fusing_xu4.sh -d $boot_disk --format -b $boot_files

}

download_archives
prepare_images
