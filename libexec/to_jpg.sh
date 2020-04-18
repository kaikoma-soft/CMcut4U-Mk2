#!/bin/sh

set -x
#
#  スクリーンショットの抽出
#
$FFMPEG \
    -loglevel $LOGLEVEL \
    -hide_banner -y \
    -i "$INPUT" \
    -r "$FRAMERATE" -f image2 -vframes "$VFOPT" \
    -vf crop=$W:$H:$X:$Y \
    -vcodec mjpeg -y "$OUTPUT"

    

