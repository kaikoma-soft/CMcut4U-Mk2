#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#


def log( str )

  now = Time.now
  str = str.class == Array ? str.join("\n         ") : str
  txt = sprintf("%s: %s\n",now.strftime("%H:%M:%S"),str)

  if $cmcutLog != nil
    makePath( $cmcutLog )
    begin 
      File.open( $cmcutLog, "a" ) do |fp|
        fp.puts( txt )
      end
    rescue => e
      p $!
      puts e.backtrace.first + ": #{e.message} (#{e.class})"
      e.backtrace[1..-1].each { |m| puts "\tfrom #{m}" }
    end
  end

  if $opt.chkng == false
    puts( txt )
  end
end


#  
#  排他制御
#
def lock()

  unless FileTest.directory?( $opt.workdir )
    FileUtils.mkpath( $opt.workdir )
  end
  
  File.open( LockFile, File::RDWR|File::CREAT, 0644) do |fl|
    if fl.flock(File::LOCK_EX|File::LOCK_NB) == false
      puts("Error: #{Pname} locked\n")
      return false
    else
      yield
    end
  end
  if test(?f, LockFile )
    #puts( "lock file delete")
    File.unlink( LockFile )
  end
  true
end


#
#  既に処理済みかチェック
#
def alreadyProc?(para, type = nil )
  if $opt.force == false
    if type == :all or ( fileValid?( para.chapfn ) and
                         FileTest.exist?( para.step4okfn ) and
                         goEnc?( para ) == false )
      if ( ret = outputChk( para.mp4fn )) != nil
        log( ret )
        $result.incOk 
        $result.encFin += 1
        return true
      end
    end
  end
  return false
end


def outputChk( fname, log = nil )
  ret = []
  if ( size = FileTest.size?( fname )) != nil
    info = Ffmpeg.new( fname ).getTSinfo( log )
    ret << sprintf("出力済み  size  = %.1f Mbyte",(size.to_f / 10 ** 6))
    ret << sprintf("           time  = %d 秒", info[:duration2] )
    return ret
  end
  nil
end

#
#  wav のframe から 0:00:00.00 形式に変換
#
def wavf2min( frame, ch = 2 )
  sec  = frame.to_f / WavRatio / ch
  h    = ( sec / 3600 ).to_i
  min  = ( ( sec - ( h * 3600))/ 60 ).to_i
  sec2 = sec % 60
  sprintf("%01d:%02d:%05.2f",h,min,sec2)
end



def makePath( path )
  dir = File.dirname( path )
  unless test( ?d, dir )
    #puts( "makedir #{dir}" )
    FileUtils.mkpath( dir )
  end
end


#
#   スレッドの終了待ち合わせ
#
def waitThreads( threads )
  if threads.size > ( $max_threads - 1 )       # 終了待ち
    threads.shift.join
  end
end


#
#   ファイルが存在して、サイズが 0 以上なら true
#
def fileValid?( file )
  if FileTest.file?( file )
    unless FileTest.zero?( file )
      return true
    end
  end
  return false
end

#
#   タイムスタンプの比較
#
def oldFile?( fname1, fname2 )
  if fileValid?( fname1 )
    mtime1 = File.mtime( fname1 )
    if fileValid?( fname2 )
      mtime2 = File.mtime( fname2 )
      if mtime1 < mtime2
        return true
      end
    else
      return true
    end
  else
    return true
  end
  false
end

#
#  sha256 の計算
#
def fileDigest( fname )
  digest = OpenSSL::Digest.new("sha256")

  list = []
  list << fname if fname.class == String
  list =  fname if fname.class == Array

  list.each do |fname|
    if FileTest.exist?( fname )
      File.open(fname) do |f|
        while data = f.read(1024)
          digest.update(data)
        end
      end
    end
  end
  digest.hexdigest
end


#
#  hash値の読み込み
#
def loadDigest( fname )
  if test( ?f, fname )
    File.open(fname) do |f|
      return f.gets.chomp
    end
  else
    return nil
  end
end


#
#  hash値の保存
#
def saveDigest( input, output )
  hash = fileDigest( input )
  File.open( output,"w") do |f|
    f.puts( hash )
  end
end

#
#  dir の直下の mp4 ファイルを削除する。
#
def delmp4( dir )
  if dir != nil and test( ?d, dir )
    Dir.entries( dir ).sort.each do |f|
      if f =~ /\.mp4$/
        log("rm #{f}")
        path = dir + "/" + f
        if test( ?f, path )
          File.unlink( path )
        end
      end
    end
  end
end

#
#  過去の計算結果と一致するかを、chapList のハッシュで判断する。
#
def goEnc?( para )

  hash_now = fileDigest( [ para.chapfn,para.fixfn ]  )
  hash_old = loadDigest( para.chapHash )
  if hash_old == nil
    log("goEnc?() old hash not found")
    return true
  end
  if hash_old != hash_now
    log("goEnc?() #hash diff")
    delmp4( para.workd )
    return true
  end

  return false
end


#
#  対象ファイルのリストアップ
#
def listTSdir( indir, zero = true )
  files = {}
  Dir.entries( indir ).sort.each do |dir|
    next if dir == "." or dir == ".."
    path1 = indir + "/" + dir
    if test(?d, path1 )
      Dir.entries( path1 ).sort.each do |fname|
        next if fname == "." or fname == ".."
        next unless fname =~ /\.(ts|mp4|ps)$/
        path2 = path1 + "/" + fname
        if zero == true and FileTest.size?( path2 ) != nil or
          zero == false and FileTest.exist?( path2 ) 
          files[dir] ||= []
          files[dir] << fname
        end
      end
    end
  end
  files
end


module Common
  

  #
  #  秒から 0:00:00.00 形式に変換
  #
  def sec2min( sec )

    h    = ( sec / 3600 ).to_i
    sec2 = ( sec - h * 3600 ) 
    min  = ( sec2 / 60 ).to_i
    sec2 = sec2 - min * 60

    sprintf("%01d:%02d:%05.2f",h,min,sec2)
  end
  module_function :sec2min


  #
  #  0:00:00.00 形式から秒に変換
  #
  def hms2sec( str )
    ret = 0.0
    if str =~ /(\d+):(\d+):([\d\.]+)/
      ret += $1.to_i * 3600
      ret += $2.to_i * 60
      ret += $3.to_f
    end
    return ret
  end
  module_function :hms2sec


  def num2ary( src )
    if src.class != Array
      tmp = []
      tmp << src if src != nil
      return tmp
    end
    src
  end

  def ary2num( src )
    if src.class == Array
      if src.size == 0
        return nil
      elsif src.size == 1
        return src[0]
      end
    end
    src
  end


  #
  #  CMの時間か判定
  #
  def cmTime?( time, gosa = 0.75 )
    15.step( 180, 15 ) do |n|
      if ( n.to_f - time ).abs < gosa
        return true
      end
    end
    return false
  end

  #
  #  n秒の判定
  #
  def cmAnyTime?( list, time, gosa = 0.75 )
    list.each do |n|
      #pp ( n.to_f - time ).abs if n == 60
      if ( n.to_f - time ).abs < gosa
        return true
      end
    end
    return false
  end
  
  
  module_function :cmAnyTime?
  module_function :cmTime?
  module_function :sec2min
  module_function :num2ary
  module_function :ary2num
  
end

