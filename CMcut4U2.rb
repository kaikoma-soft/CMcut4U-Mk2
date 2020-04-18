#!/usr/bin/ruby
# coding: utf-8
#

#
#  main 
#

require_relative 'lib/require.rb'

class Main

  def initialize(argv)
    $opt = Arguments.new(argv)
    if read_config() != nil
      $opt.setConfig()
    end
    $workFile = []
    $result = Result.new()
  end

  def interrupt()
    log("中断")
    endProc()
  end

  def endProc()
    if $workFile != nil
      $workFile.each do |fn|
        if test( ?f, fn )
          log("delete #{fn}")
          File.unlink( fn )
        end
      end
    end
    exit
  end

  
  def run()

    Signal.trap( :HUP )  { interrupt() }
    Signal.trap( :INT )  { interrupt() }

    unless FileTest.directory?( $opt.workdir )
      FileUtils.mkpath( $opt.workdir )
    end
    
    #
    # main
    #
    fileReg = $opt.regex != nil ? Regexp.new( $opt.regex ) : nil
    
    flist = {}
    plist = []
    if $opt.indir != nil
      Find.find( $opt.indir ) do |path|
        if FileTest.size?( path ) != nil
          dir = File.dirname( path )
          base = File.basename( path )
          base2 = File.basename( path, ".*" )
          if path =~ /\.(ts|ps|mp4)$/
            if fileReg == nil or fileReg =~ dir + "/" + base
              path2 = dir + "/" + base2
              flist[ path2 ] ||= []
              flist[ path2 ] << File.extname(base)
            end
          end
        end
        if FileTest.directory?(path)
          next if path == $opt.indir
          if fileReg == nil or fileReg =~ path
            plist << path
          end
        end
      end
    end

    #
    # パラメータ設定 GUI起動
    #
    if $opt.paraedit == true or $opt.empty == true
      require_relative 'lib/requireGUI.rb'
      plist.each do |path|
        para = Para.new( apath: path + "/tmp.ts", base: $opt.indir )
        if FileTest.size?(para.parafn) != nil
          fpara = para.readParaFile()
          next if $opt.empty == true
        end
        pp path
        ParaGUI.new( para.subdir, para: para )
      end
      endProc()
    end
    
    flist.keys.sort.each_with_index do |base, n|
      $cmcutLog = nil
      ext = extPriority( flist[base] )
      path = base + ext
      para = Para.new( apath: path, base: $opt.indir )
      if para.readParaFile(  ) == nil
        dir = base.sub(/#{$opt.indir}\//,'')
        log( "Error: #{dir} にパラメータが設定されていません。")
        next
      end

      next if FileTest.size?( path ) == nil
      sa = Time.now - File.mtime( path )
      if sa < 60
        log("#{base} is hot")
        next
      end

      if para.fpara.dirSkip == true            
        log("#{n+1}/#{flist.size} skip #{para.subdir}/#{para.fnbase2}")
        $result.incSkip()
        next
      end

      if $opt.fixgui == true and para.fpara.cmcut_skip == false
        require_relative 'lib/requireGUI.rb'
        Fixgui.new(para);
        next
      end
      
      log("#{n+1}/#{flist.size}  #{para.subdir}/#{para.fnbase2}")
      if $opt.ts2mp4 == true
        ts2mp4( para )
      elsif $opt.viewchk == true
        viewchk( para )
      elsif $opt.logo == true
        createLogoMode(para)
      elsif para.fpara.cmcut_skip == true
        if $opt.co == false
          return if lock { allmp4( para ) } == false
        end
      else
        if $opt.co == false
          return if lock{ cmcut( para ) } == false
        else
          cmcut( para )
        end
      end
    end

    $result.print()

    if $opt.autoremove == true
      autoremove(  )
    end

  end

  #
  #  拡張子による優先度選択
  #
  def extPriority( list )
    if list.size > 1
      priority = %w( .mp4 .ps .ts )
      ret = list.sort do |a,b|
        a2 = priority.index( a )
        b2 = priority.index( b )
        a2 <=> b2
      end
      return ret.first
    else
      return list.first
    end
  end
  
  #
  #  目視チェック
  #
  def viewchk( para )
    $cmcutLog = nil
    log("view check start")

    list = [ para.mp4fn ]
    list << para.cmmp4fn  if para.fpara.cmcut_skip == false
    found = false
    afterFix = false
    while true
      if afterFix == false
        list.each do |fn|
          if FileTest.size?( fn ) != nil
            log("found #{fn}")
            cmd = Mpv_opt.dup
            cmd << fn
            pid = system( "mpv", *cmd )
            found = true
          else
            log("not found #{fn}")
          end
        end
        break if found == false
      end
      afterFix = false
      
      print "\n> 作業完了？  (Yes/No/Fix/Retry/Quit)?"
      ans = STDIN.gets.chomp
      case ans
      when "f","F" then
        require_relative 'lib/requireGUI.rb';
        Fixgui.new(para);
        afterFix = true
        next
      when "r","R" then next ;
      when "y","Y" then cleanUp(para) ; break
      when "n","N" then break ;
      when "q","Q" then exit
      end
    end
  end

  #
  #  cmcut せずに丸ごと mp4エンコード
  #
  def allmp4( para )

    return if alreadyProc?(para, :all ) == true

    log("allmp4 start")
    stime = Time.now
    
    if FileTest.size?( para.mp4fn ) == nil
      env = { :OUTPUT   => para.mp4fn,
              :INPUT    => para.tsfn,
              :VFOPT    => [],
              :SS       => 0,
              :WIDTH    => para.tsinfo[:duration2],
              :SIZE     => NomalSize,
              :H265PRESET => "",
              :MONO     => ""
            }
      if para.fpara.monolingual == 1
        env[:MONO] = " -af pan=mono|c0=c0 "
      elsif para.fpara.monolingual == 2
        env[:MONO] = " -ac 1 -map 0:v -map 0:1 "
      end
        
      if para.fpara.deInterlace != nil and para.fpara.deInterlace != ""
        env[:VFOPT] << para.fpara.deInterlace
      end

      if para.fpara.ffmpeg_vfopt != nil
        env[ :VFOPT ] += para.fpara.ffmpeg_vfopt.split()
      end

      if para.tsinfo[:width].to_i < 1280
        h = para.tsinfo[:height].to_i
        w = para.tsinfo[:width].to_i
        env[ :SIZE ] = sprintf("%dx%d",w,h )
      end
        
      makePath( para.mp4fn )
      exec = Libexec.new(para.fpara.tomp4)
      exec.run( :tomp4, env, outfn: para.mp4fn )
    end

    lap = Time.now - stime 
    log("end   #{lap.round(2).to_s}秒\n")
  end

  
  #
  #  cmcut Main
  #
  def cmcut( para )

    return if alreadyProc?(para) == true
    
    # 初期設定
    $cmcutLog = para.cmcutLog
    if FileTest.file?( $cmcutLog )
      File.unlink( $cmcutLog )
    end
    log("cmcut start")
    stime = Time.now

    [ para.workd , para.cached ].each do |dir|
      unless FileTest.directory?(dir)
        FileUtils.mkpath( dir )
      end
    end
    para.tsinfo( para.workd + "/ffprobe.log" )

    if ! fileValid?( para.chapfn ) or $opt.force
      Step1.new.run(para)                         # step1: 前処理
      section = Step2.new.run(para)               # step2: 解析 音声
      section = Step3.new.run( para, section )    # step3: 解析 logo
    end

    ( ret, chap ) = Step4.new.run( para )         # step4: 検証
    if $opt.ngFix == true and ret == false
      require_relative 'lib/requireGUI.rb'
      Fixgui.new( para )
    end
    
    if $opt.co == false
      Step5.new.run( para, chap )                 # step5: エンコード
    end

    if FileTest.size?( para.mp4fn )
      $result.encFin += 1
    else
      $result.encWait += 1
    end

    lap = Time.now - stime 
    log("end   #{lap.round(2).to_s}秒\n")
  end

  #
  #  TS -> mp4 変換(debug用)
  #
  def ts2mp4( para )
    log("ts2mp4()")
    mp4fn = para.tsfn.sub(/\.ts/,'.mp4')
    if para.tsfn == mp4fn
      log("ts2mp4() already exists #{mp4fn}")
      return
    end

    if FileTest.size?( mp4fn ) == nil
      Ffmpeg.new( para.tsfn ).mp4enc( para, mp4fn  )
    end
  end
  
  #
  #  作業終了の後かたづけ
  #
  def cleanUp(para)
    log("cleanUp()")
    
    ts2 = Trashdir + "/" + para.subdir
    unless FileTest.directory?( ts2 )
      FileUtils.mkpath( ts2 )
    end
    to = ts2 + "/#{para.fnbase2}"
    File.rename( para.tsfn, to )
    log("TSファイルを TrashBox に移動しました。")
    FileUtils.touch( to )
    if DelTSZero == true
      FileUtils.touch( para.tsfn )
    end

  end


  #
  #  autoremove
  #  対応する TS ファイルが無くなった workDir を削除
  #
  def autoremove( )
    #log("autoremove()")

    Dir.entries( $opt.workdir ).sort.each do |dir1|
      next if dir1 == "." or dir1 == ".."
      path1 = $opt.workdir + "/" + dir1
      if test( ?d, path1 )
        Dir.entries( path1 ).sort.each do |dir2|
          next if dir2 == "." or dir2 == ".."
          path2 = path1 + "/" + dir2
          if test( ?d, path2 )
            flag = false
            %w( ts ps mp4 ).each do |ext| 
              ts = sprintf("%s/%s/%s.%s",TSdir,dir1,dir2,ext)
              if FileTest.size?( ts ) != nil
                flag = true 
                printf("+ %s\n",ts) if $opt.debug == true
              end
            end
            if flag == false
              log("work del #{dir1}/#{dir2}" )
              FileUtils.rmtree( path2 )
            end
          end
        end
      end
    end

    #
    #  期限切れになった TS ファイルの削除
    #
    limit = Time.now - TsExpireDay * 3600 * 24
    if test( ?d, Trashdir )
      Find.find( Trashdir ) do |path|
        if FileTest.size?( path ) != nil
          if path =~ /\.(ts|ps|mp4)$/
            mtime = File.mtime( path )
            if mtime < limit
              log("TsExpire: #{path}" )
              File.unlink( path )
            end
          end
        end
      end
    end


    #
    # 空になったディレクトリを削除
    #
    [ $opt.workdir, Trashdir ].each do |dir|
      if test( ?d, dir )
        Find.find( dir ) do |path|
          next if path == $opt.workdir or path == Trashdir
          if test( ?d, path )
            n = Dir.entries( path ).size
            if n == 2 
              log("rmdir #{path}"  )
              FileUtils.rmdir( path )
            end
          end
        end
      end
    end
  end

  #
  #  ロゴ作成モード
  #
  def createLogoMode(para)
    log("createLogoMode()")

    Step1.new.makeJpg( para )

    exec = Libexec.new
    args = %W( --dir #{para.picdir} ) 
    exec.run( :logoana, nil, args: args )
  end
    
end



Main.new(ARGV).run if $0 == __FILE__



