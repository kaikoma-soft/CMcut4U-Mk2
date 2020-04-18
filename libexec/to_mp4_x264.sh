#!/bin/sh

set -x
#
#   x264 エンコード 
#
$FFMPEG -loglevel $LOGLEVEL \
        -hide_banner -y \
        -analyzeduration 60M -probesize 100M \
        -ss $SS \
        -t  $WIDTH \
        -i "$INPUT" \
        $MONO \
        -vcodec libx264 -acodec aac  \
        -movflags faststart \
        -vf $VFOPT \
        -s $SIZE \
        "$OUTPUT"
