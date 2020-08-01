#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#

#
# ロゴ除去フィルター
#
def make_rmlogo_vf( para, ss = nil, w = nil )

  ret = []
  if para.fpara.rmlogofn != nil and para.fpara.rmlogofn != ""
    logopos = nil               # ロゴの位置
    enaTime = ""                # ロゴの出現時間(between化)

    if para.fpara.rmlogofn =~ /\-(\d+)x(\d+)\+(\d+)\+(\d+)\./
      logopos = [ $1, $2, $3, $4 ]
    else
      log("ロゴマスクファイル名の書式が不正です。(#{para.fpara.rmlogofn})")
      raise
    end

    if para.fpara.rmlogo_detect == true and ss != nil
      rmlogo_time = TArray.new               # ロゴの出現時間
      rmlogo_time.load( para.logoMarkfn )
      # 短い隙間は削除する。
      rmlogo_time.each_with_index do |tmp,i|
        if tmp.attr == NONE
          if tmp.w <= 6
            tmp.delMark = true
            rmlogo_time[i+1].delMark = true if rmlogo_time[i+1] != nil
          end
        end
      end
      rmlogo_time.del()
      rmlogo_time.calc()
      #puts rmlogo_time.dump

      tmp = []
      rmlogo_time.each do |t|
        next if t.attr == EOD or ( ss > ( t.t + t.w ) or t.t > ( ss + w ))
        if t.attr == LOGO
          s = t.t - ss - 2
          s = 0 if s < 0
          tmp << sprintf("between(t,%.1f,%.1f)",s , s + t.w + 3 )
        end
      end
      if tmp.size > 0
        enaTime = sprintf(":enable='%s'",tmp.join("+"))
      end
    end
    logofn = RmLogoDir + "/" + para.fpara.rmlogofn
    ( w,h,x, y ) = logopos
    blur = RmLogoBlurList[ para.fpara.rmlogo_blur ]
    blur = "null" if blur == nil

    ret = [
      "split[a][b]",
      "[a]removelogo=#{logofn}#{enaTime}[a1]",
      "[a1]crop=#{w}:#{h}:#{x}:#{y}[a2]",
      "[a2]#{blur}[a3]",
      "[b][a3]overlay=#{x}:#{y}#{enaTime}",
    ]
  end

  return ret
end

#debugText = "drawtext=text='enable':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=60:fontcolor=white#{enaTime}"
      
#
#  dir 作成
#
def mkdirs( *dirs )
  dirs.each do |dir|
    if dir != nil and dir != ""
      unless FileTest.directory?(dir)
        FileUtils.mkpath( dir )
        log( "mkdir #{dir}" ) if $opt.debug == true
      end
    end
  end
end


#
#  字幕抽出
#
def getSubtitle( para )

  if FileTest.size?( para.subtitlefn ) == nil
    env = { "INPUT" => para.tsfn,
            "OUTPUT" => para.subtitlefn,
          }
    exec = Libexec.new
    exec.run( :getAss, env, outfn: para.subtitlefn, log: para.cmcutLog  )
  end

end


#
# 字幕付加
#
def setSubtitle( infn, assfn, outfn, logfn )
  env = { "INPUT"   => infn,
          "ASSFILE" => assfn,
          "OUTPUT"  => outfn,
        }
  exec = Libexec.new
  exec.run( :setAss, env, outfn: outfn, log: logfn  )
end



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
      fns = [ para.mp4fn ]
      fns << para.mkvfn if para.subtitle? == true
      fns.each do |fn|
        if ( ret = outputChk( fn, para )) != nil
          log( ret )
          $result.incOk 
          $result.encFin += 1
          return true
        end
      end
    end
  end
  return false
end


def outputChk( fname, para, log = nil )
  ret = []
  if ( size = FileTest.size?( fname )) != nil
    ret << sprintf("出力済み  size  = %.1f Mbyte",(size.to_f / 10 ** 6))
    ret << sprintf("           time  = %d 秒", para.tsinfo[:duration2] )
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
#   複数の場合は、どれか１つでも存在すれば true
#
def fileValid?( *list )
  list.each do |fn|
    if FileTest.file?( fn )
      unless FileTest.zero?( fn )
        return true
      end
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

