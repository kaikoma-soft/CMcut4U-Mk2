#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-
#
#   コンテナを変換する。(中身はそのまま)
#
#   まれに mpv でシーク出来ないTSファイルが出来る事があるが、
#   その場合にコンテナ変換を掛けると正常にシークできるようになる。
#

require 'optparse'
Version = "1.0.0"

def usage()
  pname = File.basename($0)
    usageStr = <<"EOM"
Usage: #{pname} [Options]...  ts-file

  Options:
  -t, --ts        mpeg-TS コンテナに変換(拡張子は ts2)
  -p, --ps        mpeg-PS コンテナに変換
  -m, --mp4       mp4 コンテナに変換(デフォルト)
  -l, --link      元ファイルをリネームして、変換後ファイルへの link を作成
  --help          Show this help

#{pname} ver #{Version}
EOM
    print usageStr
    exit 1
end

$opt = {
  :cont => :mp4,
  :link => false,
}

OptionParser.new do |opt|
  opt.on('-t','--ts')  { $opt[:cont] = :ts }
  opt.on('-p','--ps')  { $opt[:cont] = :ps }
  opt.on('-m','--mp4') { $opt[:cont] = :mp4  }
  opt.on('-l','--link'){ $opt[:link] = true  }
  opt.on('--help') { usage() }
  opt.parse!(ARGV)
end

case $opt[:cont]
when :mp4
  ext = ".mp4"
  f   = "mp4"
when :ps
  ext = ".ps"
  f   = "dvd"
when :ts
  ext = ".ts2"
  f   = "mpegts"
else
  usage()
end

iname = ARGV[0]
if test( ?f, iname )
  if iname =~ /\.ts$/
    oname = iname.sub(/\.ts/, ext )
    arg = %W( ffmpeg -y -analyzeduration 100M -probesize 100M -i )
    arg << iname
    arg += %w( -max_muxing_queue_size 512 )
    arg += %w( -c:v copy -c:a copy  -map 0:v -map 0:a:0 )
    arg += %w( -bsf:a aac_adtstoasc )
    arg += %w( -bufsize 1835k -fflags genpts )
    arg += %W( -f #{f} )
    arg << oname
    p arg
    system( *arg )

    if test( ?f, oname ) and $opt[:link] == true
      org = iname + ".org"
      File.rename(iname, org )
      File.symlink( oname, iname )
    end
  end
end
