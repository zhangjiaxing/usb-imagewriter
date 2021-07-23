#!/bin/bash

if [[ "$EUID" != "0" ]]; then
    echo 'run this as root'
    exit 1
fi

if [[ "$#" != "1" ]]; then
    echo "usage: bash $0  \$image-file"
    exit 2
fi

check_commands () {
  for COMMAND in grep parted findmnt; do
    if ! command -v $COMMAND > /dev/null; then
      FAIL_REASON="$COMMAND not found"
      return 1
    fi
  done
  return 0
}


check_mounts () {
  for point in /dev /sys /proc; do
    if ! findmnt "${point}" -n >/dev/null; then
      FAIL_REASON="${point} not mounted"
      return 1
    fi
  done
  return 0
}


get_variables () {
    local ROOT_PART_DEV=$(findmnt / -o source -n)
	local ROOT_PART_NAME=$(echo "$ROOT_PART_DEV" | cut -d "/" -f 3)
	local ROOT_DEV_NAME=$(echo /sys/block/*/"${ROOT_PART_NAME}" | cut -d "/" -f 4)

	ROOT_DEV="/dev/${ROOT_DEV_NAME}"
	# ROOT_PART_NUM=$(cat "/sys/block/${ROOT_DEV_NAME}/${ROOT_PART_NAME}/partition")
	
	local BOOT_PART_DEV=$(findmnt /boot -o source -n)
	local BOOT_PART_NAME=$(echo "$BOOT_PART_DEV" | cut -d "/" -f 3)
	local BOOT_DEV_NAME=$(echo /sys/block/*/"${BOOT_PART_NAME}" | cut -d "/" -f 4)

	BOOT_DEV="/dev/${BOOT_DEV_NAME}"
	# BOOT_PART_NUM=$(cat "/sys/block/${BOOT_DEV_NAME}/${BOOT_PART_NAME}/partition")
}


select_disk () {
    get_variables
    
    local DISK_LIST=`parted --list -m | grep '^/dev/sd' | grep -v -F "${ROOT_DEV}" |
                    grep -v -F "${BOOT_DEV}" | awk -F ':' '{ print $1":"$2":"$7 }' | tr ' ' '_'`
    
    let DISK_NUM=`echo "${DISK_LIST}" | wc -l`
    let "$DISK_NUM==0" && return 1
    # let "$DISK_NUM==1" && { echo "${DISK_LIST}" ; return 0; }
    
    select disk in $DISK_LIST ; do
        [[ "$disk" = "" ]] && continue
        
        echo "$disk" | cut -d ':' -f 1
        break
    done
}


dd_display_progress () {
# $1  image
# $2  disk

    local DD_VERSION=`dd --version | head -n1 | cut -d ' ' -f 3`
    if expr "${DD_VERSION}" '>=' "8.25" >/dev/null 2>&1 ; then
        local OPTS=(status=progress bs=1M)
        echo dd if="$1" of="$2" "${OPTS[@]}"
        dd if="$1" of="$2" $OPTS &
        local PID="$!"
    else
        echo dd if="$1" of="$2" bs=1M
        dd if="$1" of="$2" &
        local PID="$!"

        ( sleep 5; while test -d /proc/$PID ; do kill -USR1 "$PID"; sleep 60; done )&
    fi

    wait "$PID"

    if [[ "$?" == "0" ]]; then
        echo -e "\033[01;32m[ $2 write done ]\033[0m\n"
    else
        echo -e "\033[01;31m[ $2 write failed ]\033[0m\n"
    fi
}


umount_device () {
    # $1 : device
    # echo umount "$1"?
    umount "$1"? &> /dev/null
    sleep 1
    umount "$1"? &> /dev/null

    if findmnt -lno source | grep "$1" -qs ; then
        echo "ERROR: $1 is mounted" >&2
        return 1
    else
        echo "$1 not mounted"
        return 0
    fi
}


main () {
    if [[ ! ( check_commands && check_mounts )  ]] ; then
        echo "$FAIL_REASON" >&2
        exit 1
    fi

    local disk=`select_disk`
    
    if test -z "$disk" ; then
        echo "disk not found" >&2
        exit 2
    fi
    
    echo "disk = ${disk}"
    if ! umount_device "$disk" >/dev/null 2>&1 ; then
        echo 'umount failed' >&2
        exit 3
    fi

    dd_display_progress "$1" "$disk"

    sync
    sync
    sleep 3
    echo eject $disk
    eject $disk
    # udisksctl power-off -b $disk
}


if [[ "$EUID" != "0" ]]; then
    echo 'run this as root' >&2
    exit 1
fi

if [[ "$#" != "1" ]]; then
    echo "usage: bash $0  \$image-file" >&2
    exit 2
fi


main "$1"
