#!/bin/sh

set -x
#
#   部分 mp4 を結合する。
#
$FFMPEG \
    -loglevel $LOGLEVEL  -hide_banner \
    -f concat -safe 0 \
    -i "$INPUT" \
    -c:v copy -c:a copy \
    -y "$OUTPUT" 

#
#  メタ情報の付加
#
if [ -s "$OUTPUT" ]
then
    TMP="$OUTPUT".tmp
    $FFMPEG \
        -loglevel $LOGLEVEL  -hide_banner \
        -i "$OUTPUT" \
        -i "$METAFN" \
        -map_metadata 1 \
        -c copy  \
        -f mp4 \
        -y "$TMP"

    if [ -s "$TMP" ]
    then
        mv "$TMP" "$OUTPUT"     # 成功
    else
        echo "Error: メタ情報の付加に失敗しました。"
    fi
else
    echo "Error: mp4 の結合に失敗しました。"
fi
