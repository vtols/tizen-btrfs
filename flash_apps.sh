#!/bin/bash

DIR=$PWD
ARCHIVES=${DIR}/archives

function message() {
    echo -e "\033[1m${1}\033[0m"
}

function download_archives() {
    mkdir -p $ARCHIVES
    message "Downloading opengl drivers and Tizen sample apps..."
    pushd $ARCHIVES
    wget -c -i ${DIR}/apps-drivers.urls
    ln -sf master.zip apps.zip
    ln -sf opengl-es-mali-t628.tar.gz opengl.tar.gz
    popd
}

function flash_apps {
    td=$(mktemp -d -p $ARCHIVES)
    message "Unpacking apps..."
    pushd $ARCHIVES
    unzip apps.zip -d $td
    pushd $td/exampleApp-master
    message "Pushing apps to odroid..."
    sudo ./patch-demo
    popd
    popd
    rm -rf $td
}

function flash_drivers {
    td=$(mktemp -d -p $ARCHIVES)
    message "Unpacking opengl drivers..."
    pushd $ARCHIVES
    tar zxvf opengl.tar.gz -C $td
    pushd $td/opengl-es-mali-t628/install-set
    message "Pushing opengl drivers to odroid..."
    sudo ./setup
    popd
    popd
    rm -rf $td
}


download_archives
flash_apps
flash_drivers
