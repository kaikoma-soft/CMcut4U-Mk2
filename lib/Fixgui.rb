#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'gtk2'


class Fixgui

  def setPara( dir, file, para = nil )
    path = sprintf("%s/%s/%s", $opt.indir,dir,file)
    @var[ :dir ] = dir
    @var[ :tsfile ] = file
    @var[ :sdata ] = nil
    @newFix = nil
    if para == nil
      @para = Para.new( apath: path, base: $opt.indir )
      @para.readParaFile( )
    end
    if @para.fpara.containerConv == true
      @var[ :tspath ] = @para.psfn
    else
      @var[ :tspath ] = path
    end
  end
  
  def initialize( para = nil )

    # 共通パラメータ保存場所
    @var = { :cb2Count => 0,
             :player   => :mpv,
           }
    @para = para if para != nil

    @opt = {
      :sa => TotalGosa,             # 許容誤差
      :x  => 0,                     # window position x
      :y  => 0,                     # window position y
    }

    #
    # 前準備
    #
    tsFiles = listTSdir( $opt.indir )
    dirs = tsFiles.keys.sort
    #Signal.trap( :INT ) { cleanUp(); exit() }

    #
    #  GUI 作成
    #
    window = Gtk::Window.new
    window.name = "main window"

    window.set_default_size(800, 600)
    window.signal_connect("destroy"){ cleanUp(); Gtk.main_quit  }
    
    # vbox1
    vbox1 = Gtk::VBox.new(false, 5)
    window.add(vbox1)
    dummy = Gtk::Label.new("")
    vbox1.pack_start(dummy, false, false, 0)

    #
    #  TSファイル選択
    # 
    frame1 = Gtk::Frame.new("対象TSファイル")
    vbox1.pack_start(frame1, false, false, 0)

    # vbox2
    vbox2 = Gtk::VBox.new(false, 5)
    frame1.add(vbox2)

    # dir 選択
    cb1 = Gtk::ComboBox.new
    n = ( dirs.size / 25 ).to_i + 1
    cb1.wrap_width = n
    dirIindex = nil
    dirs.each_with_index do |dir,n|
      cb1.append_text( dir )
      if @para != nil and dir == @para.subdir 
        dirIindex = n
      end
    end
    cb1.set_active( dirIindex ) if dirIindex != nil
    vbox2.add(cb1)

    # TS ファイル選択
    cb2 = Gtk::ComboBox.new
    vbox2.add(cb2)

    
    cb1.signal_connect("changed") do |widget|
      dir = widget.active_text
      @var[ :dir ] = dir
      if tsFiles[ dir ] != nil
        @var[ :cb2Count ].times { cb2.remove_text(0) }
        n = 0
        tsFiles[ dir ].each do |file|
          cb2.append_text( file )
          n += 1
        end
        @var[ :cb2Count ] = n
      end
    end
    
    cb2.signal_connect("changed") do |widget|
      dir = cb1.active_text
      file = cb2.active_text
      if dir != nil and file != nil
        setPara( dir, file )
      end
    end

    hbox2 = Gtk::HBox.new(false, 10)
    vbox1.pack_start(hbox2, false, false, 10)

    #
    #  コマンドボタン
    #
    bon1 = Gtk::Button.new("計算")
    hbox2.pack_start(bon1, false, false, 5)
    bon1.signal_connect("clicked") do
      calc( @var, window ) if @para != nil
    end

    bon2 = Gtk::Button.new("mpv 起動/終了")
    hbox2.pack_start(bon2, false, true, 5)
    bon2.signal_connect("clicked") do
      openMpv( @var ) if @para != nil
    end

    bon7 = Gtk::Button.new("変更書き込み")
    hbox2.pack_start(bon7, false, false, 5)
    bon7.signal_connect("clicked") do
      writeFix( window ) if @para != nil
    end
    
    bon6 = Gtk::Button.new("現在の計算値を期待値として追加")
    hbox2.pack_start(bon6, false, true, 5)
    bon6.signal_connect("clicked") do
      addPara( window  ) if @para != nil
    end

    # bon3 = Gtk::Button.new("logo抽出")
    # hbox2.pack_start(bon3, false, true, 5)
    # bon3.signal_connect("clicked") do
    #   execLogoAna( @var )
    # end

    # bon3 = Gtk::Button.new("エンコード")
    # hbox2.pack_start(bon3, false, true, 5)
    # bon3.signal_connect("clicked") do
    #   encode( @var )
    # end

    bon5 = Gtk::Button.new("パラメータ設定")
    hbox2.pack_start(bon5, false, true, 5)
    bon5.signal_connect("clicked") do
      execLTE( @var )
    end


    bon4 = Gtk::Button.new("終了")
    hbox2.pack_start(bon4, false, true, 5)
    bon4.signal_connect("clicked") do
      Thread.new do
        begin
          openMpv( @var, true )
          cleanUp()
        rescue
        end
      end
      window.destroy
      Gtk.main_quit
    end

    #
    #  表
    #
    @style = {
      :bw => Gtk::Style.new.
               set_fg(Gtk::STATE_NORMAL, 0, 0, 0).
               set_bg(Gtk::STATE_NORMAL, 0xffff, 0xffff,0xffff),
      :br => Gtk::Style.new.
               set_fg(Gtk::STATE_NORMAL, 0, 0, 0).
               set_bg(Gtk::STATE_NORMAL, 0xffff, 0xf400,0xf400),
      :bg => Gtk::Style.new.
               set_fg(Gtk::STATE_NORMAL, 0, 0, 0).
               set_bg(Gtk::STATE_NORMAL, 0xf400, 0xffff,0xf400),
      :gg => Gtk::Style.new.
               set_fg(Gtk::STATE_NORMAL, 0xb000, 0xb000, 0xb000).
               set_bg(Gtk::STATE_NORMAL, 0xb000, 0xb000, 0xb000),
    }


    sw = Gtk::ScrolledWindow.new(nil, nil)
    sw.shadow_type = Gtk::SHADOW_ETCHED_IN
    sw.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC )
    sw.set_style(@style[:bw])
    vbox1.add(sw)

    tbl = Gtk::Table.new(2, 30, false)
    tble = Gtk::EventBox.new.add(tbl)
    tble.style = @style[:gg]

    @var[:table] = tbl
    @var[:tablee] = tble
    @var[:sw] = sw
    @tblarg = [ Gtk::FILL,Gtk::FILL, 1, 1 ]

    #
    #  空状態の表作成
    # 
    setTitle( tbl )
    arg = [ Gtk::FILL,Gtk::FILL, 1, 1 ]
    0.upto(6).each do |r|
      1.upto(30).each do |c|
        if c % 2 > 0
          style = @style[:bg]
        else
          style = @style[:br]
        end
        label = Gtk::Label.new( "" ) # sprintf("%d-%d",r,c)
        eventbox = Gtk::EventBox.new.add(label)
        eventbox.style = style
        tbl.attach( eventbox, r, r+1, c, c+1, *@tblarg )
      end
    end

    sw.add_with_viewport(tble)


    #
    #  期待値と計算値
    #
    arg = [ Gtk::FILL,Gtk::FILL, 8, 2 ]
    tbl = Gtk::Table.new(2, 3, false)
    label = Gtk::Label.new("期待値")
    tbl.attach( label, 1, 2, 0, 1, *arg )
    label = Gtk::Label.new("計算値")
    tbl.attach( label, 2, 3, 0, 1, *arg )
    label = Gtk::Label.new("結果")
    tbl.attach( label, 3, 4, 0, 1, *arg )
    label = Gtk::Label.new("チャプター")
    tbl.attach( label, 0, 1, 1, 2, *arg )
    label = Gtk::Label.new("時間")
    tbl.attach( label, 0, 1, 2, 3, *arg )
    @var[:ce] = Gtk::Label.new("-") # チャプター・期待値
    tbl.attach( @var[:ce], 1, 2, 1, 2, *arg )
    @var[:de] = Gtk::Label.new("-") # 時間・期待値
    tbl.attach( @var[:de], 1, 2, 2, 3, *arg )
    @var[:cc] = Gtk::Label.new("-") # チャプター・計算値
    tbl.attach( @var[:cc], 2, 3, 1, 2, *arg )
    @var[:dc] = Gtk::Label.new("-") # 時間・計算値
    tbl.attach( @var[:dc], 2, 3, 2, 3, *arg )
    @var[:cr] = Gtk::Label.new("-") # チャプター・結果
    tbl.attach( @var[:cr], 3, 4, 1, 2, *arg )
    @var[:dr] = Gtk::Label.new("-") # 時間・結果
    tbl.attach( @var[:dr], 3, 4, 2, 3, *arg )

    vbox1.pack_start(tbl, false, false, 10)


    #
    #  --ngfix で呼ばれた時の処理
    #
    if dirIindex != nil
      cb2.append_text( @para.fnbase2 )
      cb2.set_active( 0 )
      @var[ :cb2Count ] = 1

      readChap(@var, window )
    end

    @status_bar = Gtk::Statusbar.new
    vbox1.pack_start(@status_bar, false, true, 5)

    window.show_all
    window.move( @opt[:x],@opt[:y] )

    Gtk.main

  end
  
end
