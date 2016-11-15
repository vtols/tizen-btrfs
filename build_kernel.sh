#!/bin/bash

TOOLCHAIN_RELEASE=latest-5
TOOLCHAIN_XZ=gcc-linaro-5.3.1-2016.05-x86_64_arm-linux-gnueabi.tar.xz
TOOLCHAIN_URL=http://releases.linaro.org/components/toolchain/binaries/${TOOLCHAIN_RELEASE}/arm-linux-gnueabi/${TOOLCHAIN_XZ}
TOOLCHAIN=toolchain/bin

KERNEL_SRC=linux-exynos

export ARCH=arm
#export CROSS_COMPILE=arm-linux-gnueabihf-
export CROSS_COMPILE=arm-linux-gnueabi-
export CCACHE=ccache

export PATH=${PATH}:${PWD}/toolchain/bin
ARGS=$@

function message() {
    echo -e "\033[1m${1}\033[0m"
}

function clone_repository {
    if ! [ -d $KERNEL_SRC ]; then
        message "Cloning kernel source repository..."
        git clone \
            --depth=1 \
            -b accepted/tizen_common \
            --single-branch \
            git://git.tizen.org/platform/kernel/linux-exynos \
            $KERNEL_SRC
    fi
}

function download_toolchain {
    if ! [ -d $TOOLCHAIN ]; then
        message "Downloading toolchain"
        wget -nc -O toolchain.tar.xz $TOOLCHAIN_URL
        message "Unpacking toolchain"
        tar xf toolchain.tar.xz
        mv gcc-linaro-* toolchain
    fi
}

function build_kernel {
    cd $KERNEL_SRC

    make tizen_odroid_defconfig
    for arg in $ARGS
    do
        case $arg in
            "--btrfs")
                message "Enabling btrfs support"
                ./scripts/config \
                    --enable CONFIG_BTRFS_FS \
                    --enable CONFIG_BTRFS_FS_POSIX_ACL 
                ;;
            "--no-wireless")
                message "Disabling wireless support"
                ./scripts/config \
                    --disable CONFIG_CFG80211 \
                    --disable CONFIG_MAC80211 
                ;;
        esac
    done
    make olddefconfig
    
    message "Building kernel"
    make -j$(($(nproc)+2)) zImage
}

clone_repository
download_toolchain
build_kernel
