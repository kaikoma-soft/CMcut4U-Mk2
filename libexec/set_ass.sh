#!/bin/sh

set -x
#
#  字幕の追加
#
$FFMPEG \
    -loglevel $LOGLEVEL \
    -i "$INPUT" \
    -f ass -i "$ASSFILE" \
    -c:v copy -c:a copy -c:s copy -map 0:v -map 0:a -map 1:0 \
    -metadata:s:s:0 language=jpn  \
    -y "$OUTPUT"



