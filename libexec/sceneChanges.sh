#!/bin/sh

set -x
#
#   シーンチェンジ検出
#
$FFMPEG \
    -loglevel info \
    -hide_banner -y \
    -i "$INPUT" \
    -filter:v "select='gt(scene,0.08)',showinfo" -f null - 2> "$OUTPUT"

