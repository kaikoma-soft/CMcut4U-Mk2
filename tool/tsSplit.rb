#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#
#   TSファイルを 指定した秒数で分割する。 (デフォルト)
#           又は,一定の無音期間で分割する ( --sd )
#
require 'optparse'
require 'fileutils'
require 'pp'
require 'benchmark'
require 'wav-file'

$: << ( base = File.dirname( $0 ))
$: << ( base2 = File.dirname( base ))
$: << base2 + "/lib"
#pp $:
require "const.rb"
require "common.rb"
require 'ffprob.rb'
require "Ffmpeg.rb"



def wavAnalysis( wavfn: nil ,wavratio: 4410, th: 5.0 )

  return if wavfn == nil or ! test( ?f, wavfn )

  f = open(wavfn)
  format, chunks = WavFile::readAll(f)
  f.close
  #puts format.to_s
  dataChunk = nil
  chunks.each{|c|
    #puts "> #{c.name} #{c.size}"
    dataChunk = c if c.name == 'data' # find data chank
  }
  if dataChunk == nil
    puts 'no data chunk'
    exit 1
  end

  bit = 's*' if format.bitPerSample == 16 # int16_t
  bit = 'c*' if format.bitPerSample == 8  # signed char
  wavs = dataChunk.data.unpack(bit)       # read binary

  r = []
  f = 0
  zs = nil
  count = 1
  prev = nil
  th2 = wavratio * th  # th 秒以上
  if format.channel == 1
    wavs.each do |i|
      if i < 3                 # 無音レベル
        zs = f if zs == nil    # start
      else
        if zs != nil
          if ( f - zs ) > th2   # th 秒以上
            lap = ""
            if prev != nil
              lap = "(" + f2min( f - prev,1 ) + ")"
            end
            mid = (f + zs ) / 2
            w =  ( f - zs ).to_f / wavratio
            printf("%3d %s - %s - %s  %5.1f  %s\n",
                   count,f2min( zs,1), f2min( mid,1), f2min( f,1), w,lap)
            r << [ zs ,mid, f, w ]
            count += 1
            prev = f
          end
          zs = nil
        end
      end
      f += 1
    end
  else
    raise
  end
  r
end


def search( data, th, wavratio: 4410 )
  r = []
  count = 1
  prev = nil
  data.each do |tmp|
    ( ts, tm, te, w ) = tmp
    if w > th 
      lap = ""
      if prev != nil
        if $opt[:c] == :mid 
          lap = "(" + f2min( tm - prev,1 ) + ")"
        else
          lap = "(" + f2min( te - prev,1 ) + ")"
        end
      end
      printf("%3d %s - %s - %s  %5.1f  %s\n",
             count,f2min( ts,1), f2min( tm,1), f2min( te,1), w,lap)
      count += 1
      if $opt[:c] == :mid 
        prev = tm
        r << tm / wavratio
      else
        prev = te 
        r << te / wavratio
      end
    end
  end
  r
end


#
#   分割
#
def  tssplit( input, sdata )

  ext = File.extname( input )
  output = File.basename( input,ext )
  output.sub!(/#\d+[・\-] #\d+/,'')
  output.sub!(/\s+$/,'')

  count = $opt[:n]
  sdata.each do |tmp|
    of = sprintf("%s #%02d%s",output,count,ext)
    cmd = %W(  -loglevel fatal -hide_banner -ss #{tmp[0].to_s} -i )
    cmd << input
    cmd += %W( -t #{tmp[1].to_s} -vcodec copy -acodec copy )
    cmd << of
    #pp cmd.join(" ")
    if test( ?f, of )
      return raise "output file already exist"
    end
    system2( "ffmpeg", *cmd ) if $opt[:d] == false
    count += 1
  end
end


#
#  frame から 0:00:00.00 形式に変換
#
def f2min( frame, ch = 2, ratio = 4410 )
  sec  = frame.to_f / ratio / ch
  h    = ( sec / 3600 ).to_i
  min  = ( ( sec - ( h * 3600))/ 60 ).to_i
  sec2 = sec % 60
  sprintf("%01d:%02d:%05.2f",h,min,sec2)
end

#
#  0:00:00.00 形式から秒に変換
#
def hmd2sec( str )
  if str =~ /(\d+):(\d+):(\d+\.\d+|\d+)/
    h = $1.to_i * 3600
    m = $2.to_i * 60
    s = $3.to_f
    return s + m + h
  end
  nil
end

#
#  実行時間表示付き system
#
def system2( bin, *cmd )

  printf("%s %s",bin,cmd.join(" ") )
  t = Benchmark.realtime { system(bin, *cmd ) }
  printf("\n%.2f Sec\n",t )
end



#
#  main 
#

$opt = {
  :t   => 1800,                 # 分割する秒数
  :n   => 1,                    # ナンバリングの開始番号
  :s   => 0,                    # 頭出し(skip)の秒数
  :d   => false,                # debug
  :D   => false,                # dummy
  :sd  => false,                # silence detection
  :m   => 1.0,                  # マージン(秒)
  :th  => 5.0,                  # 検出する無音期間(秒)
  :ts  => 2.0,                  # 探索開始 (--sd1指定時)
  :te  => 6.0,                  # 探索終了 (--sd1指定時)
  :tw  => 1.0,                  # 探索幅   (--sd1指定時)
  :c   => :end,                 # 切り出し方 (:mid = 真ん中、:end = 端 )
}

OptionParser.new do |opt|
  opt.on('-t n') { |v| $opt[:t] = v.to_i }
  opt.on('-n n') { |v| $opt[:n] = v.to_i }
  opt.on('-s n') { |v| $opt[:s] = v.to_i }
  opt.on('-m n') { |v| $opt[:m] = v.to_f }
  opt.on('-d')   { |v| $opt[:d] = true }
  opt.on('--sd1')  { |v| $opt[:sd] = 1 }
  opt.on('--sd2')  { |v| $opt[:sd] = 2 }
  opt.on('--th n') { |v| $opt[:th] = v.to_f }
  opt.on('--ts n') { |v| $opt[:ts] = v.to_f }
  opt.on('--te n') { |v| $opt[:te] = v.to_f }
  opt.on('--tw n') { |v| $opt[:tw] = v.to_f }
  opt.on('-e')     { |v| $opt[:c] = :end }
  opt.on('-M')     { |v| $opt[:c] = :mid }
  opt.parse!(ARGV)
end


infile = ARGV.first
wav = nil

unless test(?f, infile )
  printf("file not found %s\n",infile )
  exit
end

#
#  無音期間でカットの前処理
#
if $opt[:sd] != false
  if infile =~ /\.ts$/
    # wav に変換
    wavfn = File.basename(infile).sub(/\.ts$/,".wav" )
    if test(?f, wavfn )
      printf("file already exists %s\n",wavfn )
    else
      ff = Ffmpeg.new( infile )
      opt = { :outfn => wavfn }
      ff.ts2wav( opt )
    end
    if test(?f, wavfn )
      wav = ffprobe( wavfn )
    else
      raise
    end
  else
    raise "file name illegal"
  end
end


#
# split data  の作成
#
sdata = []                      
if wavfn != nil

  yamlfn = wavfn.sub(/\.wav$/,'.yaml')
  if test(?f, yamlfn )
    data = YAML.load_file( yamlfn )
  else
    data = wavAnalysis( wavfn: wavfn, wavratio: wav[:ratio], th: 1.0 )
    File.open( yamlfn,"w") do |fp|
      fp.puts YAML.dump( data )
    end
  end
    
  if $opt[:sd] == 1
    $opt[:ts].step( $opt[:te], $opt[:tw])  do |th|
      printf("--th %.1f\n",th.round(1) )
      printf(" No    start        mid           end     width      lap\n")
      search( data, th )
      puts("")
    end
    puts("--sd2 と --th X.X を指定して、再度実行して下さい。")
    exit
  elsif $opt[:sd] == 2
    data2 = search( data, $opt[:th] )
    st = 0
    data2 << wav[:duration2] if data2.size > 0
    data2.each_with_index do |d,n|
      sdata << [ st.round(1), (d + $opt[:m] - st ).round(1)]
      st = d - $opt[:m]
    end
  end
else
  r = ffprobe( infile )
  dra = r[:duration2] 
  sdata << dra if sdata.size > 0
  
  time = $opt[:s] 
  while time < dra
    t = time - $opt[:m]
    t = 0 if t < 0
    sdata << [ t, $opt[:t] + $opt[:m] ]
    time += $opt[:t] 
  end
  
end

tssplit( infile, sdata )

