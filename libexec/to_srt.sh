#!/bin/sh

set -x
#
#  字幕の抽出
#
$FFMPEG \
    -loglevel $LOGLEVEL \
    -hide_banner -y \
    -analyzeduration 100M -probesize 100M \
    -fix_sub_duration -aribb24-skip-ruby-text 0 \
    -i "$INPUT" \
    -f srt -y "$OUTPUT"

    

