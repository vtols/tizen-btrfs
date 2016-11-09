#!/bin/bash

DIR=$(pwd)
ARCH_DIRS=$DIR/archives

boot_disk=$1

function download_archives() {
    if [ ! -d $$ARCH_DIRS ]; then
        mkdir -p $ARCH_DIRS
    fi
    pushd $ARCH_DIRS
    wget -nc -i ../files.urls
    cp *boot-armv7* boot.tar.gz
    cp *wayland* firmware.tar.gz
    cp master.zip apps.zip
    cp opengl-es-mali-t628.tar.gz opengl.tar.gz
    popd
}

function prepare_images {
    ./repack
}

function fuse_sdcard {
    boot_files=$(cat ${ARCH_DIRS}/files.urls | head -n 2)
    ./sd_fusing_xu4.sh -d $boot_disk --format -b $boot_files

}

download_archives
