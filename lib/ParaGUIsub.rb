# coding: utf-8
#!/usr/bin/ruby
# -*- coding: utf-8 -*-



class ParaGUI

  #
  #  logoファイルのリストアップ
  #
  def listLogoDir()
    files = [  ]
    if test( ?d , LogoDir )
      Find.find( LogoDir ) do |f|
        if f =~ /\.(jpg|png|gif)$/
          fname = File.basename( f )
          next if fname =~ /^logo-\d+\.png/
          fname = f.sub(/#{LogoDir}/,'')
          fname.sub!(/^\//,'')
          files << fname
        end
      end
    end
    files << LogoNotUseTxt    
    files
  end

  #
  #  listLogoDir() の再帰版(シンボリックリンクを追う)
  #
  def listLogoDir2( dir )
    files = []
    Dir.entries( dir ).sort.each do |fname|
      next if fname == "." or fname == ".."
      path = dir + "/" + fname
      if FileTest.directory?( path ) 
        files += listLogoDir2( path )
      elsif test( ?f , path )
        if fname =~ /\.(jpg|png|gif)$/
          next if fname =~ /^logo-\d+\.png/
          fname = path.sub(/#{LogoDir}/,'')
          fname.sub!(/^\//,'')
          files << fname
        end
      end
    end
    files
  end
  
  #
  #  TS ディレクトリのリストアップ
  #
  def tsDir( dir )
    files = []
    Dir.entries( dir ).sort.each do |fname|
      next if fname == "." or fname == ".."
      path = dir + "/" + fname
      if FileTest.directory?( path ) 
        files << path
        files += tsDir( path )
      end
    end
    files
  end
  

  #
  #  shファイルのリストアップ
  #
  def listShells()
    files = [ "デフォルト" ]
    Find.find( $opt.appdir + "/libexec" ) do |f|
      if f =~ /\.(sh|rb)$/
        fname = File.basename( f )
        fname.sub!(/^\//,'')
        files << fname
      end
    end
    files
  end





  #
  #   読み込む & 設定
  #
  def set_val( ws, dir = nil )

    # 空の状態に初期化
    ws[:hlf].set_active(-1)
    ws[:clf].set_active(-1)
    ws[:lp_tr].active = true
    10.times.each do |n|
      ws[:cs][n].set_text("")
      ws[:dr][n].set_text("")
    end
    ws[:opt_id].active=(false)
    ws[:opt_cs].active=(false)
    ws[:opt_nhk].active=(false)
    ws[:opt_fadeout].active=(false)
    ws[:opt_mono].active=(false)
    ws[:opt_mono1].active=(true)
    ws[:opt_mono2].active=(false)
    ws[:opt_vfopt].set_text("")
    ws[:opt_termstime].set_text("")
    ws[:opt_sponsor_search].active=(false)
    ws[:opt_cm5sec].active=(false)
    ws[:opt_cm10sec].active=(false)
    ws[:opt_cm15sec].active=(false)
    ws[:opt_cm20sec].active=(false)
    ws[:opt_cm30sec].active=(false)
    ws[:opt_cm50sec].active=(false)
    ws[:opt_cm60sec].active=(false)
    ws[:opt_cm90sec].active=(false)
    ws[:opt_containerConv].active=(false)
    ws[:tomp4].set_active(-1)
    ws[:deInterlace].set_active(-1)
    ws[:opt_sponor_10sec].active=(false)

    
    # 値をセット
    if dir != nil
      path = sprintf("%s/%s/para.yaml",$opt.indir, dir )
      @fpara = ParaFile.new.readPara( fn: path, subdir: dir )

      if @fpara != nil
        @fpara.logofn.delete(nil)
        if @fpara.audio_only == true
          if ( n = @logoFiles.index( LogoNotUseTxt )) != nil 
            ws[:hlf].set_active(n)
          end
        else
          if @fpara.logofn != nil and @fpara.logofn.size > 0
            tmp = @fpara.logofn[0].sub(/#{LogoDir}\//,'')
            if ( n = @logoFiles.index( tmp )) != nil 
              ws[:hlf].set_active(n)
            end
          end
        end

        @fpara.cmlogofn.delete(nil)
        if @fpara.cmlogofn != nil and @fpara.cmlogofn.size > 0
          tmp = @fpara.cmlogofn[0].sub(/#{LogoDir}\//,'')
          if ( n = @logoFiles.index( tmp )) != nil 
            ws[:clf].set_active(n)
          end
        end
        
        if @fpara.position != nil
          case @fpara.position
          when "top-right"    then ws[:lp_tr].active = true
          when "top-left"     then ws[:lp_tl].active = true
          when "bottom-left"  then ws[:lp_bl].active = true
          when "bottom-right" then ws[:lp_br].active = true
          end
        end
        
        @fpara.chapNum.sort.each_with_index do |v,n|
          ws[:cs][n].set_text(v.to_s)
        end

        @fpara.duration.sort.each_with_index do |v,n|
          break if n > DuraN - 1
          ws[:dr][n].set_text(v.to_s)
        end

        if @fpara.dirSkip 
          ws[:opt_id].active=(true)
        end

        if @fpara.cmcut_skip
          ws[:opt_cs].active=(true)
        end

        if @fpara.ffmpeg_vfopt != nil
          ws[:opt_vfopt].set_text(@fpara.ffmpeg_vfopt )
        end
        
        if @fpara.fadeOut
          ws[:opt_fadeout].active=(true)
        end
        

        if @fpara.nhk_type
          ws[:opt_nhk].active=(true)
        end
        
        if @fpara.monolingual != nil
          mode = @fpara.monolingual.to_i
          ws[:opt_mono].active = true if mode > 0
          case mode
          when 1 then ws[:opt_mono1].active = true
          when 2 then ws[:opt_mono2].active = true
          end
        end

        if @fpara.terminator_stime != nil
          ws[:opt_termstime].set_text(@fpara.terminator_stime.to_s)
        end
        
        if @fpara.sponsor_search
          ws[:opt_sponsor_search].active=(true)
        end

        if @fpara.cmSec.include?(5)
          ws[:opt_cm5sec].active=(true)
        end

        if @fpara.cmSec.include?(10)
          ws[:opt_cm10sec].active=(true)
        end

        if @fpara.cmSec.include?(15)
          ws[:opt_cm15sec].active=(true)
        end

        if @fpara.cmSec.include?(20)
          ws[:opt_cm20sec].active=(true)
        end
        if @fpara.cmSec.include?(30)
          ws[:opt_cm30sec].active=(true)
        end

        if @fpara.cmSec.include?(50)
          ws[:opt_cm50sec].active=(true)
        end

        if @fpara.cmSec.include?(60)
          ws[:opt_cm60sec].active=(true)
        end

        if @fpara.cmSec.include?(90)
          ws[:opt_cm90sec].active=(true)
        end

        if @fpara.containerConv
          ws[:opt_containerConv].active=(true)
        end

        if @fpara.sponor_10sec
          ws[:opt_sponor_10sec].active=(true)
        end
        
        fn = @fpara.tomp4 != nil ? @fpara.tomp4 : "デフォルト"
        if ( n = @shellFiles.index( fn )) != nil
          ws[:tomp4].set_active(n)
        end

        fn = @fpara.deInterlace != nil ? @fpara.deInterlace : DefaultDeInterlace
        if ( n = DeInterlaceList.index( fn )) != nil
          ws[:deInterlace].set_active(n)
        end
        
      end
    end
  end
  
  #
  #   保存
  #
  def save( ws, dir )

    return if dir == nil

    logofn = ws[:hlf].active_text
    if LogoNotUseTxt == logofn 
      @fpara.logofn   = [ ]
      @fpara.audio_only = true
    else
      @fpara.logofn   = [ logofn ]
      @fpara.audio_only = false
    end

    cmlogofn = ws[:clf].active_text
    if LogoNotUseTxt == cmlogofn 
      @fpara.cmlogofn = [  ]
    else
      @fpara.cmlogofn = [ cmlogofn ]
    end

    if ws[:lp_tr].active?
      @fpara.position = "top-right"
    elsif  ws[:lp_tl].active?
      @fpara.position = "top-left" 
    elsif ws[:lp_bl].active?
      @fpara.position = "bottom-left"  
    elsif ws[:lp_br].active?
      @fpara.position = "bottom-right"
    end

    @fpara.chapNum = []
    @fpara.duration = []
    10.times.each do |n|
      tmp = ws[:cs][n].text.strip.to_i
      @fpara.chapNum << tmp if tmp != nil and tmp > 0
      tmp = ws[:dr][n].text.strip.to_i
      @fpara.duration << tmp if tmp != nil and tmp > 0
    end

    @fpara.dirSkip = ws[:opt_id].active?     ? true : false
    @fpara.cmcut_skip = ws[:opt_cs].active?  ? true : false
    @fpara.nhk_type = ws[:opt_nhk].active?     ? true : false
    @fpara.fadeOut = ws[:opt_fadeout].active?   ? true : false

    if ws[:opt_mono].active?
      @fpara.monolingual = 1 if ws[:opt_mono1].active?
      @fpara.monolingual = 2 if ws[:opt_mono2].active?
    else
      @fpara.monolingual = 0
    end

    tmp = ws[:opt_vfopt].text
    if tmp != nil
      @fpara.ffmpeg_vfopt = tmp
    end

    tmp = ws[:opt_termstime].text
    if tmp != nil and tmp != ""
      @fpara.terminator_stime = tmp.to_f
    end

    @fpara.sponsor_search = ws[:opt_sponsor_search].active?   ? true : false
    @fpara.cmSec = []
    @fpara.cmSec << 5 if ws[:opt_cm5sec].active? 
    @fpara.cmSec << 10 if ws[:opt_cm10sec].active? 
    @fpara.cmSec << 15 if ws[:opt_cm15sec].active? 
    @fpara.cmSec << 20 if ws[:opt_cm20sec].active? 
    @fpara.cmSec << 30 if ws[:opt_cm30sec].active? 
    @fpara.cmSec << 50 if ws[:opt_cm50sec].active? 
    @fpara.cmSec << 60 if ws[:opt_cm60sec].active? 
    @fpara.cmSec << 90 if ws[:opt_cm90sec].active? 
    @fpara.containerConv = ws[:opt_containerConv].active?  ? true : false

    @fpara.tomp4 = ws[:tomp4].active_text
    @fpara.deInterlace = ws[:deInterlace].active_text
    @fpara.deInterlace = "" if @fpara.deInterlace == NoInterlace
    @fpara.sponor_10sec = ws[:opt_sponor_10sec].active? ? true : false
    
    path = sprintf("%s/%s/para.yaml",$opt.indir, dir )
    @fpara.save( path, para: @para )

  end

end
