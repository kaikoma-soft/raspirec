#! /bin/bash

#
#  hls 変換スクリプト
#
#   パラメータの受け渡しは、下記の環境変数で行う
#
#   SOURCE_CMD    チューナーの起動コマンド
#   SOURCE_OUT    "-" or ffmpeg 入力ファイル名
#   STREAM_DIR    出力先ディレクトリ
#   PLAYLIST      PLAYLIST 出力ファイル名

#PATH=/usr/bin:/usr/local/bin:/bin:$PATH

#set -x

if cd $STREAM_DIR
then
    exec > ts2hls.log 2>&1
    
    $SOURCE_CMD "$SOURCE_OUT" | \
    ffmpeg  \
        -re \
        -i pipe:0 \
        -bsf:v h264_mp4toannexb \
        -movflags faststart \
        -max_muxing_queue_size 1024 \
        -analyzeduration 10M -probesize 10M  \
        -map 0:v:0 -map 0:a -ignore_unknown \
        -c:v h264 -g 10 \
        -vf "fps=10,yadif=0:-1:1" \
        -c:a copy \
        -flags +cgop+global_header \
        -f hls \
        -hls_time 5 -hls_list_size 3 -hls_allow_cache 0 \
        -hls_flags delete_segments \
        -hls_segment_filename stream_%05d.ts \
        "$PLAYLIST" \
        > ffmpeg.log 2>&1
else
    echo "dir not found $STREAM_DIR "
fi
