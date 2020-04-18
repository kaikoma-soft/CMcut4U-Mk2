#!/bin/sh

set -x
#
#  スクリーンショット生成
#
$FFMPEG -loglevel $LOGLEVEL \
        -hide_banner -y \
         -i "$INPUT" \
         -r 2 -f image2 -vframes $FRAMES \
         -vf $VFOPT \
         -vcodec mjpeg -y 
         "$OUTPUT"

