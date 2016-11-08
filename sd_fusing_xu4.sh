#!/bin/bash

declare FORMAT=""
declare DEVICE=""

# Binaires array for fusing
declare -a FUSING_BINARY_ARRAY
declare -i FUSING_BINARY_NUM=0

declare CONV_ASCII=""
declare -i FUS_ENTRY_NUM=0
declare -r FUSING_IMG="fusing.img"

# binary name | part number | offset | bs
declare -a PART_TABLE=(
	"bl1.bin.hardkernel"		""	1	512
	"bl2.bin.hardkernel.1mb_uboot"	""	31	512
	"u-boot-mmc.bin"		""	63	512
	"tzsw.bin.hardkernel"		""	2111	512
	"params.bin"			""	6272	512
	"boot.img"			p1	0	512
	"rootfs.img"			p2	0	4M
	"system-data.img"		p3	0	4M
	"user.img"			p5	0	4M
	"modules.img"			p6	0	512
	$FUSING_IMG			""	3072	512
	)

declare -r -i PART_TABLE_ROW=4
declare -r -i PART_TABLE_COL=${#PART_TABLE[*]}/${PART_TABLE_ROW}

# partition table support
function get_index_use_name () {
	local -r binary_name=$1

	for ((idx=0;idx<$PART_TABLE_COL;idx++)); do
		if [ ${PART_TABLE[idx * ${PART_TABLE_ROW} + 0]} == $binary_name ]; then
			return $idx
		fi
	done

	# return out of bound index
	return $idx
}

# fusing feature
function convert_num_to_ascii () {
	local number=$1

	CONV_ASCII=$(printf \\$(printf '%03o' $number))
}

function print_message () {
	local color=$1
	local message=$2

	tput setaf $color
	tput bold
	echo ""
	echo $message
	tput sgr 0
}

function add_fusing_entry () {
	local name=$1
	local offset=$2
	local size=$3

	FUS_ENTRY_NUM=$((FUS_ENTRY_NUM + 1))

	echo -n "$name" > entry_name
	cat entry_name /dev/zero | head -c 32 >> entry

	echo -n "" > entry_offset
	for ((i=0; i < 4; i++))
	do
		declare -i var;
		var=$(( ($offset >> (i*8)) & 0xFF ))
		convert_num_to_ascii $var
		echo -n $CONV_ASCII > tmp
		cat tmp /dev/zero | head -c 1 >> entry_offset
	done
	cat entry_offset /dev/zero | head -c 4 >> entry

	echo -n "" > entry_size
	for ((i=0; i < 4; i++))
	do
		declare -i var;
		var=$(( ($size >> (i*8)) & 0xFF ))
		convert_num_to_ascii $var
		echo -n $CONV_ASCII > tmp
		cat tmp /dev/zero | head -c 1 >> entry_size
	done
	cat entry_size /dev/zero | head -c 4 >> entry

	rm tmp
	rm entry_name
	rm entry_offset
	rm entry_size
}

function make_fusing_header () {
	# header magic
	echo -n "BFUS" > fus_hdr_magic
	cat fus_hdr_magic | head -c 4 > fus_hdr

	# entry number: 1 byte
	convert_num_to_ascii $FUS_ENTRY_NUM
	echo -n $CONV_ASCII > fus_hdr_entry_num
	cat fus_hdr_entry_num /dev/zero | head -c 4 >> fus_hdr

	rm fus_hdr_magic
	rm fus_hdr_entry_num
}

function make_fusing_struct {
	if [ -f entry ];then
		make_fusing_header
		cat fus_hdr entry /dev/zero | head -c 512 > $FUSING_IMG
		rm fus_hdr entry

		# Write Fusing Magic Number */
		fusing_image $FUSING_IMG
		rm $FUSING_IMG
	fi
}

function fusing_image () {
	local -r fusing_img=$1

	# get binary info using basename
	get_index_use_name $(basename $fusing_img)
	local -r -i part_idx=$?

	if [ $part_idx -ne $PART_TABLE_COL ];then
		local -r device=$DEVICE${PART_TABLE[${part_idx} * ${PART_TABLE_ROW} + 1]}
		local -r seek=${PART_TABLE[${part_idx} * ${PART_TABLE_ROW} + 2]}
		local -r bs=${PART_TABLE[${part_idx} * ${PART_TABLE_ROW} + 3]}
	else
		echo "Not supported binary: $fusing_img"
		return
	fi

	local -r input_size=`du -b $fusing_img | awk '{print $1}'`

	print_message 2 "[Fusing $1]"
	dd if=$fusing_img | pv -s $input_size | dd of=$device seek=$seek bs=$bs

	if [ $(basename $fusing_img) == "u-boot-mmc.bin" ];then
		add_fusing_entry "u-boot" $seek 2048
	fi
}

function fuse_image_tarball () {
	local -r filepath=$1
	local -r temp_dir="tar_tmp"

	mkdir -p $temp_dir
	tar xvf $filepath -C $temp_dir
	cd $temp_dir

	for file in *
	do
		fusing_image $file
	done

	cd ..
	rm -rf $temp_dir
	eval sync
}

function fuse_image () {

	if [ "$FUSING_BINARY_NUM" == 0 ]; then
		return
	fi

	for ((fuse_idx = 0 ; fuse_idx < $FUSING_BINARY_NUM ; fuse_idx++))
	do
		local filename=${FUSING_BINARY_ARRAY[fuse_idx]}

		case "$filename" in
		    *.tar | *.tar.gz)
			fuse_image_tarball $filename
			;;
		    *)
			fusing_image $filename
			;;
		esac
	done
	echo ""
}

# partition format
function mkpart_3 () {
	local -r DISK=$DEVICE
	local -r SIZE=`sfdisk -s $DISK`
	local -r SIZE_MB=$((SIZE >> 10))

	local -r BOOT_SZ=64
	local -r ROOTFS_SZ=3072
	local -r DATA_SZ=512
	local -r MODULE_SZ=20

	let "USER_SZ = $SIZE_MB - $BOOT_SZ - $ROOTFS_SZ - $DATA_SZ - $MODULE_SZ - 4"

	local -r BOOT=BOOT
	local -r ROOTFS=rootfs
	local -r SYSTEMDATA=system-data
	local -r USER=user
	local -r MODULE=modules

	if [[ $USER_SZ -le 100 ]]
	then
		echo "We recommend to use more than 4GB disk"
		exit 0
	fi

	echo "========================================"
	echo "Label          dev           size"
	echo "========================================"
	echo $BOOT"		" $DISK"1  	" $BOOT_SZ "MB"
	echo $ROOTFS"		" $DISK"2  	" $ROOTFS_SZ "MB"
	echo $SYSTEMDATA"	" $DISK"3  	" $DATA_SZ "MB"
	echo "[Extend]""	" $DISK"4"
	echo " "$USER"		" $DISK"5  	" $USER_SZ "MB"
	echo " "$MODULE"		" $DISK"6  	" $MODULE_SZ "MB"

	local MOUNT_LIST=`mount | grep $DISK | awk '{print $1}'`
	for mnt in $MOUNT_LIST
	do
		umount $mnt
	done

	echo "Remove partition table..."                                                
	dd if=/dev/zero of=$DISK bs=512 count=16 conv=notrunc

        # NOTE: if your sfdisk version is less than 2.26.0, then you should use following sfdisk command:
	# sfdisk --in-order --Linux --unit M $DISK <<-__EOF__

	# NOTE: sfdisk 2.26 doesn't support units other than sectors and marks --unit option as deprecated.
	# The input data needs to contain multipliers (MiB) instead.

	sfdisk $DISK <<-__EOF__
        4MiB,${BOOT_SZ}MiB,0xE,*
        8MiB,${ROOTFS_SZ}MiB,,-
        8MiB,${DATA_SZ}MiB,,-
        8MiB,,E,-
        ,${USER_SZ}MiB,,-
        ,${MODULE_SZ}MiB,,-
	__EOF__

	mkfs.vfat -F 16 ${DISK}p1 -n $BOOT
	mkfs.ext4 -q ${DISK}p2 -L $ROOTFS -F
	mkfs.ext4 -q ${DISK}p3 -L $SYSTEMDATA -F
	mkfs.ext4 -q ${DISK}p5 -L $USER -F
	mkfs.ext4 -q ${DISK}p6 -L $MODULE -F
}

function show_usage () {
	echo "- Usage:"
	echo "	sudo ./sd_fusing*.sh -d <device> [-b <path> <path> ..] [--format]"
}

function check_partition_format () {
	if [ "$FORMAT" != "2" ]; then
		echo "-----------------------"
		echo "Skip $DEVICE format"
		echo "-----------------------"
		return 0
	fi

	echo "-------------------------------"
	echo "Start $DEVICE format"
	echo ""
	mkpart_3
	echo "End $DEVICE format"
	echo "-------------------------------"
	echo ""
}

function check_args () {
	if [ "$DEVICE" == "" ]; then
		echo "$(tput setaf 1)$(tput bold)- Device node is empty!"
		show_usage
    		tput sgr 0
		exit 0
	fi

	if [ "$DEVICE" != "" ]; then
		echo "Device: $DEVICE"
	fi

	if [ "$FUSING_BINARY_NUM" != 0 ]; then
		echo "Fusing binary: "
		for ((bid = 0 ; bid < $FUSING_BINARY_NUM ; bid++))
		do
			echo "  ${FUSING_BINARY_ARRAY[bid]}"
		done
		echo ""
	fi

	if [ "$FORMAT" == "1" ]; then
		echo ""
		echo "$(tput setaf 3)$(tput bold)$DEVICE will be formatted, Is it OK? [y/n]"
   		tput sgr 0
		read input
		if [ "$input" == "y" ] || [ "$input" == "Y" ]; then
			FORMAT=2
		else
			FORMAT=0
		fi
	fi
}

function print_logo () {
	echo ""
	echo "Odroid-XU4 downloader, version 0.5"
	echo "Authors: Inha Song <ideal.song@samsung.com>"
	echo ""
}

print_logo

function add_fusing_binary() {
	local declare binary_name=$1
	FUSING_BINARY_ARRAY[$FUSING_BINARY_NUM]=$binary_name

	FUSING_BINARY_NUM=$((FUSING_BINARY_NUM + 1))
}


declare -i binary_option=0

while test $# -ne 0; do
	option=$1
	shift

	case $option in
	--f | --format)
		FORMAT="1"
		binary_option=0
		;;
	-d)
		DEVICE=$1
		binary_option=0
		shift
		;;
	-b)
		add_fusing_binary $1
		binary_option=1
		shift
		;;
	*)
		if [ $binary_option == 1 ];then
			add_fusing_binary $option
		else
			echo "Unkown command: $option"
			exit
		fi
		;;
	esac
done

check_args
check_partition_format
fuse_image

make_fusing_struct
