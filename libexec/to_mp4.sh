#!/bin/sh

set -x
#
#   x265 エンコード
#
$FFMPEG \
    -loglevel $LOGLEVEL \
    -hide_banner -y \
    -analyzeduration 60M -probesize 100M \
    -ss $SS \
    -t  $WIDTH \
    -i "$INPUT" \
    -max_muxing_queue_size 512 \
    $MONO \
    -vcodec libx265 -acodec aac -movflags faststart \
    -x265-params --log-level=error \
    -vf $VFOPT \
    -s $SIZE \
    $H265PRESET \
    "$OUTPUT"
