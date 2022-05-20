#!/bin/sh

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <path to bootloader to patch> <command line>"
    exit 1
fi

BOOTLOADER=$1
COMMAND_LINE=$2

BOOTLOADER_SIZE=`od -Ax -s -j508 -N2 $BOOTLOADER | head -n1 | cut -b10-`
if [ "$?" -ne 0 ]; then
    echo "could not read bootloader $BOOTLOADER"
    exit 2
fi
BOOTLOADER_SIZE=`expr $BOOTLOADER_SIZE + 512`

COMMAND_LINE_OFFSET=`expr $BOOTLOADER_SIZE - 54`

COMMAND_LINE_FILE=$(mktemp command-size.XXXXXX)
echo $COMMAND_LINE > $COMMAND_LINE_FILE

COMMAND_LINE_LENGTH=${#COMMAND_LINE}

dd ibs=1 count=$COMMAND_LINE_LENGTH if=$COMMAND_LINE_FILE obs=1 count=$COMMAND_LINE_LENGTH \
   seek=$COMMAND_LINE_OFFSET of=$BOOTLOADER conv=notrunc 2> /dev/null
if [ "$?" -ne 0 ]; then
    echo "could not patch bootloader $BOOTLOADER"
    exit 3
fi

rm $COMMAND_LINE_FILE
