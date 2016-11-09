#!/bin/bash

TOOLCHAIN_RELEASE=14.09
TOOLCHAIN_XZ=gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.xz
TOOLCHAIN_URL=http://releases.linaro.org/${TOOLCHAIN_RELEASE}/components/toolchain/binaries/${TOOLCHAIN_XZ}
TOOLCHAIN=toolchain/bin

KERNEL_SRC=linux-exynos

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
export CCACHE=ccache

export PATH=${PATH}:${PWD}/toolchain/bin

function clone_repository {
    if ! [ -d $KERNEL_SRC ]; then
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
        wget -nc -O toolchain.tar.xz $TOOLCHAIN_URL
        tar xvf toolchain.tar.xz
        mv gcc-linaro-* toolchain
    fi
}

function build_kernel {
    cd $KERNEL_SRC
    make tizen_odroid_defconfig
    for arg in $@
    do
        case arg in
            "--btrfs")
                ./scripts/config \
                    --enable CONFIG_BTRFS_FS \
                    --enable CONFIG_BTRFS_FS_POSIX_ACL 
                ;;
            "--no-wireless")
                ./scripts/config \
                    --disable CONFIG_CFG80211 \
                    --disable CONFIG_MAC80211 
                ;;
        esac
    done
    make -j8 zImage
}

clone_repository
download_toolchain
build_kernel
