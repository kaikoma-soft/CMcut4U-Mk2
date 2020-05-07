#!/bin/sh

set -x
#
#  TS -> mp4 コンテナ変換
#
$FFMPEG \
    -loglevel $LOGLEVEL \
    -hide_banner -y \
    -analyzeduration 100M -probesize 100M \
    -i "$INPUT" \
    -c:v copy -c:a copy -map 0:v -map 0:a -bsf:a aac_adtstoasc \
    -bufsize 1835k -fflags genpts -f mp4 \
    "$OUTPUT"

