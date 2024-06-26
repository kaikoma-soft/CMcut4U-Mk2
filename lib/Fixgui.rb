#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'gtk3'


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

  def set_margin( w, t, r, b , l )
    w.set_margin_top( t )
    w.set_margin_left( l )
    w.set_margin_right( r )
    w.set_margin_bottom( b )
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
    @opt[:x] = FixguiPosition[:x] if FixguiPosition[:x] != nil
    @opt[:y] = FixguiPosition[:y] if FixguiPosition[:y] != nil

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
    vbox1 = Gtk::Box.new(:vertical, 5) 
    window.add(vbox1)
    dummy = Gtk::Label.new("")
    vbox1.pack_start(dummy, :expand => false, :fill => false, :padding => 2)

    #
    #  TSファイル選択
    # 
    tmp = frame1 = Gtk::Frame.new("対象TSファイル")
    set_margin( tmp, 1, 5, 0, 5 )
    vbox1.pack_start(frame1, :expand => false, :fill => false, :padding => 5)

    # vbox2
    tmp = vbox2 = Gtk::Box.new(:vertical, 5) 
    set_margin( tmp, 1, 5, 5 , 5 )
    frame1.add(vbox2)

    # dir 選択
    cb1 = Gtk::ComboBoxText.new
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
    cb2 = Gtk::ComboBoxText.new
    vbox2.add(cb2)
    
    cb1.signal_connect("changed") do |widget|
      dir = widget.active_text
      @var[ :dir ] = dir
      if tsFiles[ dir ] != nil
        @var[ :cb2Count ].times { cb2.remove(0) }
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

    hbox2 = Gtk::Box.new(:horizontal, 10)
    vbox1.pack_start(hbox2, :expand => false, :fill => false, :padding => 5)

    #
    #  コマンドボタン
    #
    bon1 = Gtk::Button.new( :label => "計算")
    hbox2.pack_start(bon1, :expand => false, :fill => false, :padding => 5)
    bon1.signal_connect("clicked") do
      calc( @var, window ) if @para != nil
    end

    bon2 = Gtk::Button.new( :label => "mpv 起動/終了")
    hbox2.pack_start(bon2, :expand => false, :fill => true, :padding => 5)
    bon2.signal_connect("clicked") do
      openMpv( @var ) if @para != nil
    end

    bon7 = Gtk::Button.new( :label => "変更書き込み")
    hbox2.pack_start(bon7, :expand => false, :fill => false, :padding => 5)
    bon7.signal_connect("clicked") do
      writeFix( window ) if @para != nil
    end
    
    bon6 = Gtk::Button.new( :label => "現在の計算値を期待値として追加")
    hbox2.pack_start(bon6, :expand => false, :fill => false, :padding => 5)
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

    bon5 = Gtk::Button.new( :label => "パラメータ設定")
    hbox2.pack_start(bon5, :expand => false, :fill => false, :padding => 5)
    bon5.signal_connect("clicked") do
      execLTE( @var )
    end


    bon4 = Gtk::Button.new( :label => "終了")
    hbox2.pack_start(bon4, :expand => false, :fill => false, :padding => 5)
    bon4.signal_connect("clicked") do
      openMpv( @var, true )
      cleanUp()
      window.destroy
      Gtk.main_quit
    end

    #
    #  表
    #

    # 16進で color 指定
    def get_hex_color( r,g,b )
      return Gdk::RGBA::new( r.to_f / 0xffff,  g.to_f / 0xffff, b.to_f / 0xffff,  1.0)
    end
    
    @color = {        
      :red     => get_hex_color( 0xffff, 0xe000, 0xe000 ),
      :white   => get_hex_color( 0xffff, 0xffff, 0xffff ),
      :gray    => get_hex_color( 0xb000, 0xb000, 0xb000 ),
      :gray2   => get_hex_color( 0xac00, 0xac00, 0xac00 ),
      :green   => get_hex_color( 0xe000, 0xffff, 0xe000 )
    }
    
    sw = Gtk::ScrolledWindow.new
    sw.shadow_type = :none
    sw.set_policy(:automatic,:automatic)

    tbl = Gtk::Grid.new
    tbl.row_spacing    = 0
    tbl.column_spacing = 0
    tbl.margin_top     = 10
    tbl.margin_bottom  = 10
    tbl.set_vexpand( true )
    tbl.set_hexpand( true )
    
    tble = Gtk::EventBox.new.add(tbl)
    @var[:table] = tbl
    @var[:tablee] = tble
    @var[:sw] = sw

    vbox1.pack_start( sw, :expand => true, :fill => true, :padding => 0)
    
    #
    #  空状態の表作成
    # 
    setTitle( tbl )
    0.upto(6).each do |r|
      1.upto(30).each do |c|
        if c % 2 > 0
          bgc = @color[:green]
        else
          bgc = @color[:red]
        end
        label = Gtk::Label.new( sprintf("%d-%d",r,c) )
        eventbox = Gtk::EventBox.new.add(label)
        eventbox.set_border_width(1)
        eventbox.set_hexpand( true )
        
        label.override_background_color( :normal, bgc )
        tbl.attach( eventbox, r, c, 1, 1 ) # for grid
      end
    end

    sw.add_with_viewport(tble)

    #
    #  期待値と計算値
    #
    tbl = Gtk::Grid.new()
    tbl.row_spacing    = 5
    tbl.column_spacing = 15

    def grid_add_label( tbl, left, top, str )
      label = Gtk::Label.new( str )
      tbl.attach( label, left, top, 1, 1 )
      return label
    end
    grid_add_label( tbl, 1, 0, "期待値" )
    grid_add_label( tbl, 2, 0, "計算値" )
    grid_add_label( tbl, 3, 0, "結果" )
    grid_add_label( tbl, 0, 1, "チャプター" )
    grid_add_label( tbl, 0, 2, "時間" )
    @var[:ce] = grid_add_label( tbl, 1, 1, "-" ) # チャプター・期待値
    @var[:cc] = grid_add_label( tbl, 2, 1, "-" ) # チャプター・計算値
    @var[:cr] = grid_add_label( tbl, 3, 1, "-" ) # チャプター・結果
    @var[:de] = grid_add_label( tbl, 1, 2, "-" ) # 時間・期待値
    @var[:dc] = grid_add_label( tbl, 2, 2, "-" ) # 時間・計算値
    @var[:dr] = grid_add_label( tbl, 3, 2, "-" ) # 時間・結果
    
    vbox1.pack_start(tbl, :expand => false, :fill => false, :padding => 10)

    #
    #  --ngfix で呼ばれた時の処理
    #
    if dirIindex != nil
      cb2.append_text( @para.fnbase2 )
      cb2.set_active( 0 )
      @var[ :cb2Count ] = 1

      readChap(@var, window )
    end

    hsep = Gtk::Separator.new(:horizontal)
    vbox1.pack_start(hsep, :expand => false, :fill => true, :padding => 1)
    
    @status_bar = Gtk::Statusbar.new
    vbox1.pack_start(@status_bar, :expand => false, :fill => true, :padding => 1)

    window.show_all
    window.move( @opt[:x],@opt[:y] )

    Gtk.main

  end
  
end


