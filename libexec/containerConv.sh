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
    -max_muxing_queue_size 512 \
    -c:v copy -c:a copy  -map 0:v -map 0:a:0 \
    -bsf:a aac_adtstoasc \
    -bufsize 1835k -fflags genpts -f mp4 \
    "$OUTPUT"

