# coding: utf-8
#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#

#
#  ファイル名等の各種パラメータを生成、格納
#
class Para

  attr_accessor :tsfn,          # TSファイル名
                :basedir,       # dirname(tsfn)
                :chapHash,      # チャプターリストの hash値保存ファイルのPATH
                :chapfn,        # チャプター情報ファイル名
                :cmcutLog,      # log ファイルPATH
                :subdir,        # sub dir 名
                :fnbase,        # basename(tsfn) 拡張子なし
                :fnbase2,       # basename(tsfn) 拡張子あり
                :logoMarkfn,    # ロゴ検出データの保存ファイルのPATH
                :metafn,        # meta情報ファイルのPATH
                :mp4fn,         # 本編 mp4 ファイル PATH
                :cmmp4fn,       # CM mp4 ファイル PATH
                :parafn,        # パラメータファイルPATH
                :picdir,        # スクリーンショットDir Path
                :sceneCfn,      # シーンチェンジ検出結果ファイル名
                :wavfn,         # wav ファイルPATH
                :workd,         # 作業Dir PATH
                :wav,           # 音声データ
                :fpara,         # パラメータファイルの値の格納
                :fixfn,         # Fixファイル名
                :cached,        # データキャッシュDir
                :scene,         # シーンチェンジ データ
                :step3desfn,    # Step3 の処理の説明文
                :step4result,   # Step4の結果
                :step4okfn,     # Step4 が OK の場合に touch
                :subtitlefn,    # 字幕(ass) ファイル名
                :mkvfn,         # 字幕が有効な場合の出力ファイル名(mp4fn相当)
                :tsinfoData,    # tsinfo の結果格納
                :macro,         # CM/本編のマクロ定義
                :lockf          # ロック用ファイル
  
  def initialize( apath: nil, base: nil )
    @tsfn  = apath                 # TS file name

    if base != nil
      @basedir = base
      @subdir  = File.dirname( apath.sub(/#{base}\//,''))
    else
      @basedir = File.dirname( apath )
      @subdir  = nil
    end
    @fnbase  = File.basename( apath, ".*")
    @fnbase2 = File.basename( apath )
    @ext     = File.extname( apath ) 
    @parafn = sprintf("%s/para.yaml", File.dirname( apath ))

    if @subdir != nil
      @mp4fn  = sprintf("%s/%s/%s.mp4",$opt.outdir,@subdir,@fnbase )
      @mkvfn  = sprintf("%s/%s/%s.mkv",$opt.outdir,@subdir,@fnbase )
      @workd  = sprintf("%s/%s/%s", $opt.workdir, @subdir, fnbase )
    else
      @mp4fn  = sprintf("%s/%s.mp4",$opt.outdir,@fnbase )
      @mkvfn  = sprintf("%s/%s.mkv",$opt.outdir,@fnbase )
      @workd  = sprintf("%s/%s", $opt.workdir, fnbase )
    end
    @cmmp4fn  = @workd + "/cm-all.mp4"

    @cmcutLog  = @workd + "/cmcut.log"
    1.upto(9999).each  do |n|
      tmp = sprintf("%s/cmcut-%02d.log",@workd, n )
      next if test( ?f, tmp )
      @cmcutLog  = tmp
      break
    end
    @wavfn     = @workd + "/Tmp.wav"
    @sceneCfn  = @workd + "/SceneC.dat"
    @picdir    = @workd + "/SS"
    @metafn    = @workd + "/ffmeta.ini"
    @chapHash  = @workd + "/chapList.sha"
    @chapfn    = @workd + "/chapList.txt"
    @fixfn     = @workd + "/chapFix.txt"
    @logoMarkfn= @workd + "/logoMark.log"
    @cached    = @workd + "/Cache"
    @step3desfn= @workd + "/Cache/s3des.yaml"
    @lockf     = @workd + "/.lock"
    @cutSkip   = false
    @step4result = false
    @step4okfn = @workd + "/step4.ok"
    @subtitlefn  = @workd + "/subtitle.ass"

    readMacroFile()
    
  end

  #
  # 字幕処理をするか
  #
  def subtitle?()
    if Subtitling == true
      if @tsinfoData != nil
        if @tsinfoData[:subtitle] == true
          return true
        end
      end
    end
    return false
  end

  #
  # スクリーンショットを作るか (true=作る)
  #
  def screenS?()
    if @fpara.audio_only != true or
       ( @fpara.rmlogofn != nil and
         @fpara.rmlogofn != "" and
         @fpara.rmlogo_detect == true )
      return true
    end
    return false
  end
  
  def setLogofn( str )
    @logofn = sprintf("%s/%s",LogoDir,str )
    return nil unless test(?f,@logofn )
    @logofn
  end

  def setTsinfo(tmp)
    @tsinfoData = tmp
  end

  #
  #  TSの諸元取得
  #
  def tsinfo( log = nil )

    if @tsinfoData == nil and @tsinfoFail == nil
      tmp = Ffmpeg.new( @tsfn ).getTSinfo( @workd + "/ffprobe-in.log" )
      if tmp[:duration] == nil 
        log( "警告: duration の取得に失敗しました。コンテナ変換を行います。")
      end
      if @fpara.containerConv == true or tmp[:duration] == nil 
        if containerConv( self ) == true
          tmp2 = Ffmpeg.new( psfn ).getTSinfo( @workd + "/ffprobe-in-mp4.log" )
          if tmp2[:duration] == nil 
            log( "Error: duration の取得に失敗しました。")
            @tsinfoFail = true      # 取得に失敗
            return nil
          end
          tmp[:duration] = tmp2[:duration]
          tmp[:duration2] = tmp2[:duration2]
        else
          return nil
        end
      end
      @tsinfoData = tmp
    end

    return @tsinfoData
  end

  #
  # パラメータファイルの読み込み
  #
  def readParaFile()
    if FileTest.size?( @parafn ) != nil
      @fpara = ParaFile.new().readPara( para: self )
      @fpara.logofn.compact!
      @fpara.cmlogofn.compact!
      return @fpara
    end
    return nil
  end

  def psfn()                    # ts -> mp4 変換後のファイル名
    return @workd + "/" + @fnbase + ".mp4"
  end

  #
  # パラメータファイルの読み込み
  #
  def readMacroFile()
    @macro = nil
    macrofn = sprintf("%s/%s/macro.txt",@basedir,@subdir )
    if FileTest.size?( macrofn ) != nil
      @macro  = Macro.new
      @macro.load( macrofn )
    end
    return @macro
  end
  
end
  

