#!/bin/bash

# Make sure a partition of given LABEL exists,
# contains an xfs file system, and is mounted
# under the given MOUNTPOINT.
#
# If a corresponding partition does not exist,
# a disk of specified SIZE is searched with no
# partition, and a GPT partition is created
# spanning the whole disc, and it is nemd with
# the provided LABEL.
#
# If needed, an xfs file system is created on
# the partition, an fstab entry is created,
# and the file system is mounted.

SIZE=$1
LABEL=$2
MOUNTPOINT=$3
BRICKPATHSUFFIX=$4

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

function errecho()
{
	>&2 echo $@
}

function existing_partition_for_label()
{
	local _label=$1
	local _line=$(lsblk -n -P -o NAME,PARTLABEL | grep ${_label})
	local _dev=$(echo ${_line} | cut -d' ' -f1)

	_dev=$(echo ${_dev} | sed -e 's/NAME="//g' -e 's/"//g')

	[ -n "${_dev}" ] && {
		errecho "Partition '${_dev}' with label '${_label}' found."
	} || {
		errecho "No partition with label '${_label}' found."
	}

	echo ${_dev}
}

function locate_disk_for_size()
{
	local _size=$1
	local _candidate_devs=$(lsblk -n -l -d -o NAME,SIZE | grep ${_size} | cut -d' ' -f1)
	local _dev=""

	for _dev in ${_candidate_devs}
	do
		local __dev="/dev/${_dev}"
		parted -s ${__dev} print 1 > /dev/null 2>&1 && {
			errecho "Partition exists on ${__dev}. Skipping."
		}|| {
			errecho "Found device ${__dev} of size ${_size} without partition."
			echo -n "${__dev}"
			return
		}
	done

	errecho "No device without parition of size ${_size} found."
	echo -n ""
}

function create_partition_for_size()
{
	local _size=$1
	local _label=$2

	local _dev="$(locate_disk_for_size ${_size})"

	[ -z "${_dev}" ] && {
		echo ""
		return
	}

	parted -s "${_dev}" mklabel gpt && {
		errecho "Created GPT label on ${_dev}."
	} || {
		errecho "Failed to created GPT label on ${_dev}."
		echo ""
		return
	}

	parted -s ${_dev} mkpart primary 1 100% && {
		errecho "Created partition ${_dev}1."
		echo "${_dev}1"
	} || {
		errecho "Failed to create partition on ${_dev}."
		echo ""
	}
}

function check_xfs_fs()
{
	local _partition=$1

	( blkid -s TYPE ${_partition} | grep -q -s 'TYPE="xfs"' ) && {
		errecho "partition ${_partition} contains xfs file system."
	}
}

function make_xfs()
{
	local _partition=$1

	errecho "creating xfs filesystem on ${_partition}."

	mkfs.xfs -f ${_partition} && {
		errecho "xfs file system created on ${_partition}."
	}
}

function fail_xfs()
{
	local _partition=$1

	errecho "Could not create xfs file system on ${_partition}."

	exit 1
}

function check_fstab_entry()
{
	local _partition=$1
	local _fstab="/etc/fstab"

	grep -q -s /dev/${_partition} ${_fstab} && {
		errecho "Mount entry for ${_partition} is present in ${_fstab}."
	}
}

function create_fstab_entry()
{
	local _partition=$1
	local _mountpoint=$2
	local _fstab="/etc/fstab"

	errecho "Creating mount entry for ${_partition} in ${_fstab}."
	test -f ${_fstab} || touch ${_fstab}
	cp -f -a ${_fstab} ${_fstab}${BACKUP_SUFFIX}
	cat <<EOF >> ${_fstab}
${_partition} ${_mountpoint} xfs defaults 0 0
EOF
}

function check_mounted()
{
	local _mountpoint=$1
	mount | grep ${_mountpoint} && {
		errecho "${_mountpoint} is already mounted."
	}
}

function do_mount()
{
	local _mountpoint=$1

	errecho "Mounting ${_mountpoint}."
	mount ${_mountpoint}
}

function fail_mount()
{
	local _mountpoint=$1

	errecho "Error mounting ${_mountpoint}."

	exit 1
}


# main

PARTITION=$(existing_partition_for_label ${LABEL})
[ -z "${PARTITION}" ] && {
	PARTITION=$(create_partition_for_size ${SIZE} ${LABEL})
}
[ -z "${PARTITION}" ] && exit 1

check_xfs_fs ${PARTITION} || make_xfs ${PARTITION} || fail_xfs ${PARTITION}

mkdir -p ${MOUNTPOINT}

FSTAB=/etc/fstab

check_fstab_entry ${PARTITION} || create_fstab_entry ${PARTITION} ${MOUNTPOINT}

check_mounted ${MOUNTPOINT} || do_mount ${MOUNTPOINT} || fail_mount ${MOUNTPOINT}

mkdir -p ${MOUNTPOINT}/${BRICKPATHSUFFIX}
