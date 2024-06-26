#!/usr/bin/ruby
# -*- coding: utf-8 -*-


class Fixgui

  
  #
  # status bar メッセージ表示
  #
  def statmesg( str )
    context_id = @status_bar.get_context_id("Statusbar")
    @status_bar.push(context_id, str )
  end


  #
  # 表のタイトル表示
  #
  def setTitle( tbl )
    title = %w( チャプターNo 時間(秒) 時間(HMS) 幅(秒) 種別 コメント 種別修正)
    #arg = [ Gtk::EXPAND,Gtk::FILL, 1, 1 ]
    title.each_with_index do |str,j|
      label = Gtk::Label.new( str )
      eventbox = Gtk::EventBox.new.add(label)
      eventbox.override_background_color( :normal, @color[:gray2] )
      eventbox.set_border_width(1)
      tbl.attach( eventbox, j, 0, 1, 1 ) # for Grid
    end
  end


  #
  #  step3 の内訳表示ダイアログ
  #
  def step3des()
    d = Gtk::Dialog.new
    s3des = Step3des.new.load(@para)
    buf = []
    s3des.each do |s|
      buf << sprintf("%4s : %s",s.key, s.des)
    end
    label = Gtk::Label.new( buf.join("\n"))
    label.set_justify( :left )
    vbox1 = Gtk::Box.new(:vertical, 0 )
    vbox1.pack_start(label, :expand => true, :fill => true, :padding => 20)

    d.child.add(vbox1) 
    d.add_buttons(["Close", 1])
    d.show_all
    d.run
    d.destroy
  end

  #
  #  計算結果の表
  #
  def calcDisp( fp, data, fixdata )
    chap = 0
    oldtype = nil
    sdata2 = []
    duration = 0

    data.each_with_index do |a,i|
      dis = a.w != nil ? a.w : 0.0
      time = sprintf("%.2f",a.t )
      hms   = sprintf("%s",Common::sec2min(a.t) )
      dis   = sprintf("%5.1f",dis )
      type  = sprintf("%-7s",a.attr2str( ))
      comme = a.txt == nil ? "" : a.txt
      fix   = ""
      if ( tmp = fixdata.include?( a.t )) != nil
        fix = tmp.attr2str()
      end

      if oldtype != data[i].attr
        oldtype = data[i].attr
        chap += 1 
      end
      if a.attr == HON
        duration += a.w if a.w != nil
      end
      
      sdata2 << [ chap, time, hms, dis,type, comme, fix ]
    end

    tbl = Gtk::Grid.new
    tbl.row_spacing    = 0
    tbl.column_spacing = 0
    tbl.margin_top     = 10
    tbl.margin_bottom  = 10
    tbl.set_hexpand( true )
    @var[:tablee].remove( @var[:table] ) if @var[:tablee] != nil
    @var[:tablee].add(tbl)
    @var[:table] = tbl

    #
    # create popup menu
    #
    menu = Gtk::Menu.new
    menuItem = []
    menuItem[0] = Gtk::MenuItem.new( :label => typeStr(0) )
    menuItem[1] = Gtk::MenuItem.new( :label => typeStr(1) )
    menuItem[2] = Gtk::MenuItem.new( :label => typeStr(2) )
    menuItem.each_with_index do |mi,i|
      menu.append mi
      mi.signal_connect('activate') do |widget, event|
        n = @var[:row]
        #pp "select #{n} #{i}"
        @newFix[n][:label].text= typeStr( i )
      end
    end
    menu.show_all

    # チャプターの併合数のカウント
    chapSpan = {}
    last = sdata2.last[0]
    0.step(last) do |n|
      sdata2.each_with_index do |a,i|
        if n == a[0]
          chapSpan[n] ||= {}
          if chapSpan[n][:start] == nil
            chapSpan[n][:start] = i
            chapSpan[n][:end] = i
          else
            chapSpan[n][:end] = i
          end
        end
      end
    end

    # チャプター数：計算値
    if @var[:cc] != nil
      @var[:cc].text= chapSpan.size.to_s
      @var[:resultC] = chapSpan.size
    end

    # 時間：計算値
    if @var[:dc] != nil
      @var[:dc].text = sprintf("%.2f",duration)
      @var[:resultD] = duration
    end

    # チャプター：結果
    if @var[:cr] != nil
      if @para.fpara.chapNum.include?( chapSpan.size )
        @var[:cr].text= "○"
      else
        @var[:cr].text= "×"
      end
    end

    # 時間：結果
    if @var[:dr] != nil
      flag = false
      @para.fpara.duration.each do |d|
        next if d == nil
        if ( duration - d.to_f ).abs < TotalGosa
          flag = true
          break
        end
      end
      if flag == true
        @var[:dr].text= "○"
      else
        @var[:dr].text= "×"
      end
    end
    
    
    # 表の作成
    setTitle( tbl )
    @newFix = []
    sdata2.each_with_index do |a,i|
      style = @color[:green]
      style = @color[:red] if a[4] =~ /CM/

      eventbox = nil
      chap = a[0]
      a.each_with_index do |str,j|
        next if j == 7
        if j == 6
          label = Gtk::Label.new( str )
        else
          label = Gtk::Label.new( str.to_s )
        end
        label.set_justify( :left )
        label.set_hexpand( true )

        eventbox = Gtk::EventBox.new.add(label)
        eventbox.set_border_width(1)
        #eventbox.style = style
        eventbox.override_background_color( :normal, style )
        
        if j < 5                  # mpv seek
          eventbox.events = :button_press_mask
          eventbox.signal_connect("button_press_event") {seekMpv(i)}
        elsif j == 5        # step3des
          eventbox.events = :button_press_mask
          eventbox.signal_connect("button_press_event") do |widget, event|
            step3des()
          end
        elsif j == 6        # fix popup
          eventbox.events = :button_press_mask
          eventbox.signal_connect("button_press_event") do |widget, event|
            @var[:row] = i
            menu.popup nil, nil, event.button, event.time
          end
          @newFix << { label: label, time: a[7] }
        end
        if j == 0
          if chapSpan[chap][:start] == i 
            k = chapSpan[chap][:end] - chapSpan[chap][:start] + 1
            tbl.attach( eventbox, j, i+1, 1, k )
          end
        else
          tbl.attach( eventbox, j, i+1, 1, 1 )
        end
      end
    end

    @var[:sdata] = sdata2  # 退避
    
    tbl.show_all
  end

  #
  #  gtk のイベント処理
  #
  def gtkEventProc()
    while (Gtk.events_pending?)
      Gtk.main_iteration
    end
  end
      
  
  #
  #   計算
  #
  def calc( para, parent )

    if @para != nil
      # ダイアログの表示
      d = Gtk::Dialog.new( :title => "-",
                           :parent => parent,
                           :flags => [:modal ],
                           :buttons => nil)
      
      label = Gtk::Label.new("  ***  計算中  ***  ")
      vbox = Gtk::Box.new(:vertical, 0 )
      vbox.pack_start(label, :expand => true, :fill => true, :padding => 30)
      d.child.add( vbox )
      d.show_all
      statmesg( "計算中" )
      
      t = Thread.new do           # 待機スレッド
        sleep(0.2)
        t1 = Time.now
        @para.readParaFile( )
        @para.readMacroFile()
        Step1.new.run(@para)                         # step1: 前処理
        section = Step2.new.run(@para)               # step2: 解析 音声
        section = Step3.new.run( @para, section )    # step3: 解析 logo
        readChap( para, parent )

        tw = 0.8 - ( Time.now - t1 ).to_f
        sleep( tw ) if tw > 0                        # 最低表示期間
        d.destroy
      end
      gtkEventProc() while t.join( 0.01 ) == nil
      statmesg( "計算終了" )
    end
  end
  
  #
  #  chapList.txt の読み込み 
  #
  def readChap( para, window )

    (data, fix ) = ChapFix::load( @para )

    if data.size > 0
      calcDisp( para, data, fix ) # 表示
    end
    @rowdata = data 
                     
    if @var[:ce] != nil
      @var[:ce].text= @para.fpara.chapNum.sort.join(",")
    end
    if @var[:de] != nil
      @var[:de].text= @para.fpara.duration.sort.join(",")
    end
    
  end

  #
  #  chapFix.txt の書き込み
  #
  def writeFix( window )

    if @para != nil
      data = TArray.new
      if @newFix != nil
        @newFix.each_index do |n|
          str = @newFix[n][:label].text
          attr = case str
                 when "","-"          then NONE
                 when "本編","HonPen" then HON
                 when "CM"            then CM
                 else                 NOME
                 end
          if attr != NONE
            data.add(t: @rowdata[n].t, attr: attr )
          end
        end
      end
      data.save( @para.fixfn )
      statmesg( "fix file saved" )

      calc( @para, window )
      return data
    end
  end
  



  #
  #  mpv 起動／終了
  #
  def openMpv( para, quit = false )
    return if para[:tspath] == nil

    if quit == false and @var[:fifo] == nil
      fn = para[:tspath]

      fifo = nil
      Tempfile.open('mpv') do |f|
        fifo = f.path + ".fifo"
      end
      File.mkfifo( fifo )
      
      cmd = Mpv_opt.dup + %W( --idle --input-ipc-server=#{fifo} ) 
      cmd << fn
      
      begin
        pid = spawn( "mpv", *cmd )
        t = Thread.new do           # 終了待ちスレッド
          Thread.current.report_on_exception = false 
          Process::waitpid( pid )
          statmesg( "mpv end" )
          cleanUp()
        end
        @var[:fifo] = fifo
        $workFile << fifo
      rescue Errno::ENOENT => e
        msg = "Error: can't exec mpv"
        statmesg( msg )
        puts( msg )
      end
    else
      sendMsg("quit")
      statmesg( "mpv quit" )
    end
  end


  def execLTE( para )
    ParaGUI.new( para[:dir], para: @para )
  end



  def execLogoAna( para )

    cmd = "logoAnalysisSub.py"
    if para[:tsfile] == nil
      msg = "Error: ts file not select"
      statmesg( msg )
      puts( msg )
      return
    end
    
    base = File.basename( para[:tsfile],".ts")
    ssdir = sprintf("%s/%s/%s/SS",Workdir, para[:dir],base  )

    if test( ?d, ssdir )
      arg = %W( --dir #{ssdir} ) 
      begin
        pid = spawn( cmd, *arg )
        t = Thread.new do           # 終了待ちスレッド
          Process::waitpid( pid )
        end
      rescue Errno::ENOENT => e
        msg = "Error: can't exec #{cmd}"
        statmesg( msg )
        puts( msg )
      end
    else
      msg = "Error: screen shot dir not found : #{ssdir}"
      statmesg( msg )
      puts( msg )
    end
  end



  #
  # fifo の後始末
  #
  def cleanUp()
    if @var[:fifo] != nil
      if FileTest.pipe?( @var[:fifo] )
        #pp "unlink #{@var[:fifo]}"
        File.unlink( @var[:fifo] )
      end
      $workFile.delete( @var[:fifo] )
      @var[:fifo] = nil
    end
  end
  

  #
  #   socket にコマンド書き込み
  #
  def sendMsg( msg )
    puts( msg )
    if @var[:fifo] != nil
      s = UNIXSocket.new( @var[:fifo] )
      s.write(msg + "\n" )
      s.close
    else
      statmesg( "Error: mpv not exec" )
    end
  end


  #
  #  mpv にコマンド送信(廃止)
  #
  def mpsend_old( cmd )
    if @var[:mpfp] != nil
      #puts( cmd )
      @var[:mpfp].puts( cmd )
      @var[:mpfp].flush
    else
      statmesg( "Error: mpv not exec" )
    end
  end

  #
  #  
  #
  def seekMpv( n )
    #puts("seekMlayer(#{n})")
    
    if @var[:sdata] != nil
      sec = @var[:sdata][n][1].split[0].to_f - 1
      sec = 0 if sec < 0
      statmesg("seek #{sec.to_i} sec"  )
      sendMsg("seek #{sec.to_i} absolute\n")
    end
    
  end

  def typeStr( type )
    types = %w( - HonPen CM )
    return types[ type ]
  end


  #
  #  パラメータファイルに現在の計算値を追加
  #
  def addPara( window )

    @para.fpara.chapNum << @var[:resultC].to_i
    @para.fpara.duration << @var[:resultD].round()

    @para.fpara.chapNum.uniq!
    @para.fpara.duration.uniq!
    
    @para.fpara.save( @para.parafn )

    calc( @para, window )

  end
  

end
