#!/bin/bash

DIR=$PWD
ARCHIVES=${DIR}/archives
BUILDS=${DIR}/builds

device=$1
ARGS=$@

function message() {
    echo -e "\033[1m${1}\033[0m"
}

function download_archives() {
    mkdir -p $ARCHIVES
    message "Downloading boot, firmware, opengl drivers and Tizen  sample apps..."
    pushd $ARCHIVES
    wget -c -i ${DIR}/files.urls
    cp *boot-armv7* boot.tar.gz
    cp *wayland* firmware.tar.gz
    ln -s firmware.tar.gz firmware-ext4.tar.gz
    cp master.zip apps.zip
    cp opengl-es-mali-t628.tar.gz opengl.tar.gz
    popd
}

function prepare_images {
    pushd $ARCHIVES
    if [ ! -e $image ]; then
        message "Repacking image..."
        ${DIR}/repack.sh ${ARCHIVES}/firmware.tar.gz $comp_algo
    fi
    popd
}

function fuse_sdcard {
    message "Fusing eMMC..."
    echo $image
    sudo ./sd_fusing_xu4.sh -d $device $FORMAT -b $boot $image
    MOUNT=${ARCHIVES}/mnt
    mkdir -p $MOUNT
    sudo mount ${device}p1 $MOUNT

    message "Install Odroid boot.ini"
    sudo cp -v boot.ini $MOUNT

    message "Install kernel (zImage)"
    sudo cp -v $kernel_image ${MOUNT}/zImage

    sudo umount ${device}p1
}

function parse_options {
    image=${ARCHIVES}/firmware.tar.gz
    for arg in $ARGS
    do
        case $arg in
            "--boot")
                FORMAT="--format"
                boot=${ARCHIVES}/boot.tar.gz
                ;;
            "--fs=*")
                fs_type=$(echo $arg | sed -e 's/--fs=//')
                if [[ $fs_type =~ "btrfs-(.*)" ]]; then
                    btrfs="--btrfs"
                    comp_algo=${BASH_REMATCH[1]}
                fi
                image=${ARCHIVES}/firmware-${fs_type}.tar.gz
                ;;
        esac
    done
}

function run_build_kernel {
    if [ $btrfs ]; then
        suffix=-btrfs
    fi
    kernel_image=$BUILDS/zImage${suffix}
    if [ ! -e $kernel_image ]; then
        message "Run kernel build"
        ${DIR}/build_kernel.sh $btrfs
        mkdir -p $BUILDS
        cp ${DIR}/linux-exynos/arch/arm/boot/zImage \
            $kernel_image
    fi
}

parse_options
download_archives
prepare_images
run_build_kernel
fuse_sdcard
