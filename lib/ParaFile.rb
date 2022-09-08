#!/usr/local/bin/ruby 
# -*- coding: utf-8 -*-
#

#
#  パラメータファイルの読み書き
#
class ParaFile

  attr_accessor   :cmlogofn,
                  :logofn,
                  :duration,
                  :chapNum,
                  :position,
                  :monolingual,
                  :audio_only,
                  :ffmpeg_vfopt,
                  :fadeOut,
                  :nhk_type,
                  :dirSkip,
                  :cmcut_skip,
                  :terminator_stime,
                  :sponsor_search,
                  :cmSec,
                  :tomp4,
                  :containerConv,
                  :sponor_10sec,
                  :deInterlace,
                  :subadj,
                  :rmlogo_time,
                  :rmlogofn,
                  :rmlogo_detect,
                  :rmlogo_blur

  def initialize( )
    @rmlogofn = nil             # ロゴ除去用マスクファイル名
    @cmlogofn = []              # CM ロゴファイル名
    @logofn   = []              # 本編ロゴファイル名
    @duration = []              # 時間の期待値
    @chapNum  = []              # チャプター数の期待値
    @position       = nil       # ロゴの位置指定
    @monolingual    = nil       # 2カ国後対応
    @audio_only     = false     # logo解析を行わず、音声のみで処理する。
    @ffmpeg_vfopt   = nil       # 
    @fadeOut        = FadeOut   # FadeOut を挿入するか
    @nhk_type       = false     # 途中CM無し、前後に長い無音期間あり
    @dirSkip        = false     # このディレクトリは無視する
    @cmcut_skip     = false     # CMカット処理は行わず、丸ごと
    @terminator_stime = nil     # 区切りの無音期間の長さ
    @rmlogo_time    = nil       # ロゴの存在する時間データ。解析結果から設定
    @cmSec          = []        # n秒のセクションを強制的にCM にする。
    @tomp4          = nil       # mp4 エンコードスクリプトの指定
    @sponsor_search = false     # CMの中から提供を探して印を付ける。
    @containerConv  = false     # TS -> PS のコンテナ変換を行う
    @sponor_10sec   = false     # 本編直後にある 10秒のセクションは提供とみなす
    @deInterlace    = nil       # インタレース解除
    @subadj         = 0.0       # 字幕のタイミング調整(秒)
    @rmlogo_detect  = false     # ロゴを検出した時だけロゴ除去フィルターを掛ける
    @rmlogo_blur    = RmLogoBlurDefault # ぼかしフィルター
  end

  def createSymList( name,min,max )
    list = [ name.to_sym ] + min.upto(max).map{ |n| "#{name}#{n}".to_sym }
  end


  #
  # パラメータファイルの読み込み
  #
  def readPara( fn: nil, subdir: nil, para: nil )

    lt = {}
    parafn = para != nil ? para.parafn : fn

    if test( ?f, parafn )
      lt = YamlWrap.load_file( parafn )
      return lt.initPara()
    end
    #log("パラメータファイルが見つかりませんでした。")
    initPara()
    return self
  end

  def readParaSub( lt )
    createSymList( "cmlogofn", 0, 9 ).each do |sym|
      if lt[ sym ] != nil
        fn = sprintf("%s/%s", $opt.logodir, lt[ sym ] )
        if test( ?f, fn )
          @cmlogofn << lt[ sym ]
        else
          log("Error: logo file not found (#{fn})")
        end
      end
    end

    createSymList( "logofn", 0, 9 ).each do |sym|
      if lt[ sym ] != nil
        fn = sprintf("%s/%s", $opt.logodir, lt[ sym ] )
        if test( ?f, fn )
          @logofn << lt[ sym ]
        else
          errLog("Error: logo file not found (#{fn})")
        end
      end
    end

    createSymList( "duration", 0, 9 ).each do |sym|
      @duration << lt[ sym ] if lt[ sym ] != nil
    end
    
    createSymList( "chapNum", 0, 9 ).each do |sym|
      @chapNum << lt[ sym ] if lt[ sym ] != nil
    end
    
    @position = lt[ :position ]
    if lt[ :monolingual ] == nil # Only the right channel of audio
      @monolingual = nil
    else
      @monolingual = lt[ :monolingual ].to_i
    end
    @audio_only     = lt[ :audio_only ] 
    @ffmpeg_vfopt   = lt[ :ffmpeg_vfopt ]
    @fadeOut        = lt[ :fade_inout ]
    @nhk_type       = !!lt[ :nhk_type ]    
    @dirSkip        = !!lt[ :mp4skip ]    
    @cmcut_skip     = !!lt[ :cmcut_skip ] 
    if lt[ :mark0_stime ] != nil
      @terminator_stime = lt[:mark0_stime].to_f # mark0 の無音期間の長さ
    else
      @terminator_stime = 2.0
    end
    @rmlogo_time = nil          # ロゴの存在する時間データ。解析結果から設定
  end

  
  #
  #  パラメータファイルの保存
  #
  def save( parafn, para: nil )

    @logofn.delete(nil)
    @cmlogofn.delete(nil)
    @duration.delete(nil)
    @chapNum.delete(nil)
    @cmSec.delete(nil)

    def vdiff( old, new, name )
      a = old.instance_variable_get( name ) 
      b = new.instance_variable_get( name )
      if a != b
        #pp "#{name} : #{a} -> #{b}"
        return true
      end
      false
    end

    #
    # 古いのと比べて変更点を探し、対応処置
    #
    if para != nil
      if ( old = readPara( fn: parafn )) != nil
        delWork( :logo, para ) if vdiff( old, self, "@logofn")
        delWork( :logo, para ) if vdiff( old, self, "@cmlogofn")
        delWork( :ss  , para ) if vdiff( old, self, "@position")
        delmp4( para.workd )   if vdiff( old, self, "@tomp4" )
        delmp4( para.workd )   if vdiff( old, self, "@rmlogo" )
        delmp4( para.workd )   if vdiff( old, self, "@rmlogo_detect" )

        ["@monolingual",
         "@audio_only",
         "@ffmpeg_vfopt",
         "@fadeOut",
         "@nhk_type",
         "@dirSkip",
         "@cmcut_skip",
         "@terminator_stime",
         "@delogo",
         "@delogo_pos",
         "@cmSec",
         "@sponsor_search",
         "@containerConv",
         "@sponor_10sec",
         "@deInterlace"].each do |name|
          if vdiff( old, self, name )
            delWork( :chap, para )
            break
          end
        end
      end
    end
    save2( parafn )    
  end

  def save2( parafn )
    File.open( parafn, "w") do |fp|
      fp.puts YAML.dump( self )
    end
  end
  

  #
  #  テンポラリファイルを削除
  #
  def delWork( type, para )
    if para != nil
      list = []
      case type
      when :logo
        list << "#{para.cached}/resultH.yaml"
        list << "#{para.cached}/resultC.yaml"
      when :ss
        list << para.picdir + "/ss_00001.jpg"
      when :chap
        list << para.chapfn if para.chapfn != nil
      else
        raise
      end
      list.each do |fn|
        if test( ?f, fn  )
          log("del #{fn}")
          File.unlink( fn )
        end
      end
    end
  end
  
  #
  #  初期設定値
  #
  def initPara( )

    @position  = "top-right" if @position == nil
    @cmSec     = []          if @cmSec    == nil
    @sponsor_search = false  if @sponsor_search == nil
    @terminator_stime = 2.0  if @terminator_stime == nil
    @containerConv = false   if @containerConv == nil
    @sponor_10sec  = false   if @sponor_10sec  == nil
    @fadeOut       = FadeOut if @fadeOut == nil
    @deInterlace   = DefaultDeInterlace if @deInterlace == nil
    @audio_only    = true    if @audio_only == nil
    @monolingual   = 0       if @monolingual == nil 
    @subadj        = 0.0     if @subadj == nil
    @rmlogo_detect = false   if @rmlogo_detect == nil
    @rmlogo_blur   = RmLogoBlurDefault if @rmlogo_blur == nil

    #@chapNum   << 10
    #@duration  << 1440

    return self
  end


end
  

