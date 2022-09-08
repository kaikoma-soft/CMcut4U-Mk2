#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#
#   TSファイルを 指定した秒数で分割する。 (デフォルト)
#           又は,一定の無音期間を検出して 2stepで分割する ( --sd1,--sd2 ) 
#
require 'benchmark'
require 'optparse'
require 'nkf'
require 'yaml'
require 'wav-file'

Version = "1.0.1"
WavRatio= 4410

#
#   無音期間の抽出
#
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
              lap = "(" + f2min( f - prev,1, wavratio ) + ")"
            end
            mid = (f + zs ) / 2
            w =  ( f - zs ).to_f / wavratio
            printf("%3d %s - %s - %s  %5.1f  %s\n",
                   count,f2min( zs,1,wavratio), f2min( mid,1,wavratio), f2min( f,1,wavratio), w,lap)
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

#
#  無音データから、閾値を指定して期間の算出
#
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
          lap = "(" + f2min( tm - prev,1, wavratio) + ")"
        else
          lap = "(" + f2min( te - prev,1, wavratio ) + ")"
        end
      end
      printf("%3d %s - %s - %s  %5.1f  %s\n",
             count,f2min( ts,1, wavratio), f2min( tm,1, wavratio), f2min( te,1, wavratio), w,lap)
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
#   TSの分割
#
def  tssplit( input, sdata )

  ext = File.extname( input )
  output = File.basename( input,ext )
  output.sub!(/([・\-～])\s+/,'\1')
  output.sub!(/#\d+[・\-～][\s#]?\d+/,'')
  output.sub!(/\s+$/,'')

  count = $opt[:n]
  sdata.each do |tmp|
    of = sprintf("%s #%02d%s",output,count,ext)
    stime = tmp[0]
    stime += $opt[:shift] if stime != 0
    cmd = %W(  -loglevel fatal -hide_banner -ss #{stime.to_s} -i )
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
#  ffprobe の実行
#
def ffprobe( input )

  key = %w( codec_long_name duration  time_base )

  r = {}
  r[ :fname ] = input

  IO.popen( "ffprobe -pretty -hide_banner -show_streams \"#{input}\" 2>&1 " ) do |fp|
    fp.each_line do |line|
      line = NKF::nkf("-w",line.chomp)

      key.each do |k|
        if line =~ /^#{k}=(.*)/
          if $1 != "N/A"
            r[ k.to_sym ] = $1 if r[ k.to_sym ] == nil
          end
        elsif line =~ /^\s+Duration: (.*?),/
          r[ :duration ] = $1 if r[ :duration ] == nil
        end
      end
    end
  end

  if r[:duration] != nil
    if r[:duration] =~ /(\d):(\d+):(\d+)/
      r[:duration2] = $1.to_i * 3600 + $2.to_i * 60 + $3.to_i
    end
  end

  if r[:time_base] != nil
    r[:ratio] = r[ :time_base ].sub(/1\//,'').to_i
  end
  r
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
#  wav 変換
#
def ts2wav( tsfn, outfn )
  arg = %W( -i #{tsfn} ) +
        %W( -vn -ac 1 -ar #{WavRatio} -acodec pcm_s16le -f wav ) +
        %W( -y #{outfn} ) 
  system2( "ffmpeg", *arg )
end



def usage()
  pname = File.basename($0)
    usageStr = <<"EOM"
Usage: #{pname} [Options]...  ts-file

  Options:
    -t, --time n          分割する秒数(周期)
    -n, --num n           ナンバリングの開始番号
    -s, --skip n          先頭をずらす(秒)
    -S, --shift n         先頭以外の切り出し時間をずらす(秒)
    -m, --margin n        切り出し時の糊しろ(秒)
        --sd1             無音期間で分割 step1
        --sd2             無音期間で分割 step2
        --th n            無音期間の閾値
        --ts n            無音期間の閾値の探索開始値
        --te n            無音期間の閾値の探索終了値
        --tw n            無音期間の閾値の探索step値
    -e, --end             無音期間の切り出し方 終端
    -M, --mid             無音期間の切り出し方 真中
    -C, --cp n,m,...      指定した秒数で切り出す
        --help            Show this help

#{pname} ver #{Version}
EOM
    print usageStr
    exit 1
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
  :te  => 8.0,                  # 探索終了 (--sd1指定時)
  :tw  => 1.0,                  # 探索幅   (--sd1指定時)
  :c   => :end,                 # 切り出し方 (:mid = 真ん中、:end = 端 )
  :shift => 0.0,                # 切り出し時間をずらす(秒)
  :cp  => nil,                  # cut point で指定
}

OptionParser.new do |opt|
  opt.on('-t n','--time n')   { |v| $opt[:t] = v.to_i }
  opt.on('-n n','--num')      { |v| $opt[:n] = v.to_i }
  opt.on('-s n','--skip n')   { |v| $opt[:s] = v.to_i }
  opt.on('-m n','--margin n') { |v| $opt[:m] = v.to_f }
  opt.on('-d','--debug')      { |v| $opt[:d] = true }
  opt.on('--sd1')             { |v| $opt[:sd] = 1 }
  opt.on('--sd2')             { |v| $opt[:sd] = 2 }
  opt.on('--th n')            { |v| $opt[:th] = v.to_f }
  opt.on('--ts n')            { |v| $opt[:ts] = v.to_f }
  opt.on('--te n')            { |v| $opt[:te] = v.to_f }
  opt.on('--tw n')            { |v| $opt[:tw] = v.to_f }
  opt.on('-e','--end')        { |v| $opt[:c] = :end }
  opt.on('-M','--mid')        { |v| $opt[:c] = :mid }
  opt.on('-S n','--shift n')  { |v| $opt[:shift] = v.to_f }
  opt.on('--cp cutpoint')     { |v| $opt[:cp] = v }
  opt.on('--help')            { usage() }
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
  if infile =~ /\.(ts|mp4|ps)$/
    # wav に変換
    wavfn = File.basename(infile).sub(/\.(ts|ps|mp4)$/,".wav" )
    if test(?f, wavfn )
      printf("file already exists %s\n",wavfn )
    else
      ts2wav( infile, wavfn )
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
    data = YamlWrap.load_file( yamlfn )
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
      search( data, th, wavratio: wav[:ratio] )
      puts("")
    end
    puts("--sd2 と --th X.X を指定して、再度実行して下さい。")
    exit
  elsif $opt[:sd] == 2
    data2 = search( data, $opt[:th], wavratio: wav[:ratio] )
    st = 0
    data2 << wav[:duration2] if data2.size > 0
    data2.each_with_index do |d,n|
      sdata << [ st.round(1), (d + $opt[:m] - st ).round(1)]
      st = d - $opt[:m]
    end
  end
elsif $opt[:cp] != nil
  cutpoint = []
  $opt[:cp].split(/,/).each do |v|
    if v =~ /:/
      cutpoint << hmd2sec( v )
    else
      cutpoint << v.to_i
    end
  end
  
  r = ffprobe( infile )
  cutpoint << r[:duration2] 
  
  ptime = 0
  cutpoint.each do |n|
    sdata << [ ptime, ( n - ptime ) ]
    if ptime > n
      puts("Error: 切り出し点が昇順ではありません。#{cutpoint.to_s}")
      exit
    end
    ptime = n
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

