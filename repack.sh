#!/bin/bash

function check_btrfs() {
    support=$(cat /proc/filesystems | grep btrfs | tr -d '\t\n ')
    if [ $support ]; then
        message "Btrfs support is enabled."
    else
        message "Btrfs support is disabled." \
                "Should be enabled to run script."
        exit
    fi
}

function message() {
    echo -e "\033[1m${1}\033[0m"
}

function repack_image() {
    src_image=$1
    fs_label=$(echo ${src_image} | sed -e 's/.img//')
    echo "Process ${src_image}"

    dst_image=btrfs/${src_image}
    sz=$(stat --format=%s ${src_image})
    new_sz=$((${sz}*2))

    message "Create new btrfs image for ${image}"
    fallocate --length=${new_sz} ${dst_image}
    mkfs.btrfs $dst_image #--label=${fs_label}

    message "Mount source and destination image"
    src_dev=$(losetup --find --show ${src_image})
    dst_dev=$(losetup --find --show ${dst_image})
    mount $src_dev src_mnt
    mount -o "compress=${comp_alg}" $dst_dev dst_mnt

    message "Copying ${image} contents..."
    cp -a src_mnt/. dst_mnt
    message "Done.\n"

    if [ "$src_image" == "rootfs.img" ]; then

        message "Edit /etc/fstab in rootfs.img"
        sed -i "s/ext4/btrfs/"                         dst_mnt/etc/fstab
        sed -i "s/LABEL=system-data/\/dev\/mmcblk0p3/" dst_mnt/etc/fstab
        sed -i "s/LABEL=user/\/dev\/mmcblk0p5/"        dst_mnt/etc/fstab
        sed -i "s/defaults,/defaults,compress=${comp_alg},/" dst_mnt/etc/fstab
        cat dst_mnt/etc/fstab

        message "Edit disk resize services"
        bw_prefix=dst_mnt/usr/lib/systemd/system/basic.target.wants
        rm -v   ${bw_prefix}/resize2fs@*.service
        for i in 2 3 5; do
            ln -srv ${bw_prefix}/../resize2fs@.service \
                ${bw_prefix}/resize2fs@dev-mmcblk0p${i}.service
        done
        ls -l   ${bw_prefix}


        message "Edit systemd resize2fs@.service unit"
        sed -i 's/resize2fs -f/btrfs_resize/' \
                ${bw_prefix}/../resize2fs@.service
        cat ${bw_prefix}/../resize2fs@.service

        #Device->mountpoint: lsblk -o MOUNTPOINT -nr /dev/mmcblk0pX
        cat <<EOF > dst_mnt/sbin/btrfs_resize
#!/bin/bash

device=\$1
mountpoint=\$(/bin/lsblk -o MOUNTPOINT -nr \$device)
/sbin/btrfs filesystem resize max \$mountpoint
EOF
        chmod +x dst_mnt/sbin/btrfs_resize
        message "Written auxiliary script"
        cat dst_mnt/sbin/btrfs_resize

        message "Install btrfs tool from file"
        #Btrfs executable for armv7l from btrfs-progs
        cp ${workdir}/btrfs dst_mnt/sbin
    fi

    message "Unmount source and destination images"
    umount $src_dev $dst_dev
    losetup --detach $src_dev
    losetup --detach $dst_dev

    message "Checking filesystem"
    file ${dst_image}
}

check_btrfs

workdir=$(pwd)

snapshot=$1
comp_alg=${2:-no}

case $comp_alg in
    "no")
        message "Repacking ${snapshot}, disabled compression"
        ;;
    "zlib")
        message "Repacking ${snapshot}, enabled ZLIB compression"
        ;;
    "lzo")
        message "Repacking ${snapshot}, enabled LZO compression"
        ;;
    *)
        message "Unknown compression algo ${comp_alg}, aborting"
        exit 1
        ;;
esac

name=$(echo $snapshot | sed -e s/.tar.gz//)
new_basename=${name}-btrfs-${comp_alg}.tar.gz
new_name=$(readlink -m ${new_basename})
tmpdir=$(mktemp -d -p .)

message "Unpack original images"
tar xzvf $snapshot -C $tmpdir
echo

cd $tmpdir
image_set=$(ls)
mkdir {src_mnt,dst_mnt,btrfs}
for image in ${image_set}
do
    repack_image ${image}
done

message "Pack btrfs images"
cd btrfs; tar czvf ${new_name} *; cd ${workdir}
if [ $SUDO_USER ]; then
    chown $SUDO_USER ${new_name}
fi
message "File ${new_basename} created"

rm -rf $tmpdir
