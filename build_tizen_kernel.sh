export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

make tizen_odroid_defconfig
make menuconfig
make -j8 zImage
