#!/bin/sh

set -x
#
#   H264 エンコード nvenc 使用
#

$FFMPEG \
    -loglevel $LOGLEVEL \
    -hide_banner -y \
    -analyzeduration 60M -probesize 100M \
    -ss $SS \
    -t  $WIDTH \
    -i "$INPUT" \
    -vf $VFOPT \
    -max_muxing_queue_size 512 \
    $MONO \
    -c:v h264_nvenc -rc vbr \
    -movflags faststart \
    -s $SIZE \
    "$OUTPUT"

