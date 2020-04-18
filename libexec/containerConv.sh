#!/bin/sh

set -x
#
#  TS -> PS コンテナ変換
#
$FFMPEG \
    -loglevel $LOGLEVEL \
    -hide_banner -y \
    -analyzeduration 100M -probesize 100M \
    -i "$INPUT" \
    -c:v copy -c:a ac3  -bufsize 1835k -fflags genpts -f dvd \
    "$OUTPUT"

