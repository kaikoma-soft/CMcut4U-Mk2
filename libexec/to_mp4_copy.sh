#!/bin/sh

set -x
#
#   エンコードなし copy
#
$FFMPEG \
    -loglevel $LOGLEVEL \
    -hide_banner -y \
    -ss $SS \
    -i "$INPUT" \
    -t  $WIDTH \
    -vcodec copy -acodec copy \
    "$OUTPUT"
