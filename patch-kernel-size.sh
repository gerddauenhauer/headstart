#!/bin/sh

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <path to bootloader to patch> <path to kernel>"
    exit 1
fi

BOOTLOADER=$1
KERNEL=$2

BOOTLOADER_SIZE=`od -Ax -s -j508 -N2 $BOOTLOADER | head -n1 | cut -b10-`
if [ "$?" -ne 0 ]; then
    echo "could not read bootloader $BOOTLOADER"
    exit 2
fi
BOOTLOADER_SIZE=`expr $BOOTLOADER_SIZE + 512`

KERNEL_SIZE=`stat -c "%s" $KERNEL`
if [ "$?" -ne 0 ]; then
    echo "could not read kernel $KERNEL"
    exit 2
fi

KERNEL_SIZE_OFFSET=`expr $BOOTLOADER_SIZE - 4`

# apparently, we cannot pipe this to stdout such that dd could read from stdin.
KERNEL_SIZE_FILE=$(mktemp kernel-size.XXXXXX)
printf "0: %08x\n" $KERNEL_SIZE | \
    sed -E 's/0: (..)(..)(..)(..)/0: \4\3\2\1/' | \
    xxd -r -g0 > $KERNEL_SIZE_FILE

dd ibs=1 count=4 if=$KERNEL_SIZE_FILE obs=1 count=4 \
   seek=$KERNEL_SIZE_OFFSET of=$BOOTLOADER conv=notrunc 2> /dev/null
if [ "$?" -ne 0 ]; then
    echo "could not patch bootloader $BOOTLOADER"
    exit 3
fi

rm $KERNEL_SIZE_FILE
