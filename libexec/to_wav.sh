#!/bin/sh

set -x
#
#  音声の抽出
#
$FFMPEG \
    -loglevel $LOGLEVEL \
    -hide_banner -y \
    -i "$INPUT" \
    -vn -ac 1 -ar $WAVRATIO -acodec pcm_s16le -f wav \
    "$OUTPUT"

