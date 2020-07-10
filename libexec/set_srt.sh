#!/bin/sh

set -x
#
#  字幕の追加
#
$FFMPEG \
    -hide_banner -y \
    -loglevel $LOGLEVEL \
    -i "$INPUT" \
    -f srt -i "$SRTFILE" \
    -map 0 -map 1 -c copy -c:s copy -metadata:s:s:0 language=jpn  \
    -y "$OUTPUT"


