#!/usr/bin/ruby
# -*- coding: utf-8 -*-

#
#  para.yaml の編集 GUI
#

require 'gtk2'

class ParaGUI

  DuraN  = 10                   # duration の設定数
  LogoNotUseTxt = "使用しない (丸ごと１本 or 音声のみで処理する or CM)"
  NoInterlace   = "しない"
  
  def initialize( dir = nil, para: nil )
    @opt = {
      :dir => dir,
    }
    @para  = para
    @fpara = para.fpara

    if Object.const_defined?(:ForceCmTime) == true
      @cmTime = ForceCmTime
    else
      @cmTime = [ 3, 5, 10, 15, 20, 30, 60 ] # 未定義の場合のデフォルト
    end

    #
    # 前準備
    #
    #tsFiles = listTSdir( $opt.indir, false )
    dirs = tsDir( $opt.indir )

    @logoFiles =  listLogoDir2( LogoDir )
    @logoFiles << LogoNotUseTxt    
    @shellFiles = listShells()
    #dirs = tsFiles.keys.sort
    Signal.trap( :INT ) { exit() }
    @tblarg = [ Gtk::FILL,Gtk::EXPAND, 2, 2 ]
    ws = {}

    #
    #  GUI 作成
    #
    window = Gtk::Window.new
    window.name = "main window"

    window.set_default_size(600, 300)
    window.signal_connect("destroy"){ Gtk.main_quit  }

    # vbox1
    vbox1 = Gtk::VBox.new(false, 5)
    window.add(vbox1)

    tbl = Gtk::Table.new(10, 2, false)

    ##############
    y = 0
    label = Gtk::Label.new("対象ディレクトリ")
    tbl.attach( label, 0, 1, y, y+1, *@tblarg )

    ws[:dir] = Gtk::ComboBox.new
    n = ( dirs.size / 25 ).to_i + 1
    ws[:dir].wrap_width = n
    dirs.each_with_index do |dir,n|
      dir.sub!(/#{$opt.indir}\//,'')
      ws[:dir].append_text( dir )
      if dir == @opt[:dir]
        ws[:dir].set_active(n)
      end
    end
    tbl.attach( ws[:dir], 1, 2, y, y+1, *@tblarg )

    ws[:dir].signal_connect("changed") do |widget|
      dir = widget.active_text
      set_val( ws, dir )
    end

    ##############
    y = 1
    hsep = Gtk::HSeparator.new
    tbl.attach( hsep, 1, 2, y, y+1, *@tblarg )
    label = Gtk::Label.new("")
    tbl.attach( label, 0, 1, y, y+1, *@tblarg )

    ##############
    y = 2
    label = Gtk::Label.new("本編 logoファイル名")
    tbl.attach( label, 0, 1, y, y+1, *@tblarg )

    ws[:hlf] = Gtk::ComboBox.new
    n = ( @logoFiles.size / 25 ).to_i + 1
    ws[:hlf].wrap_width = n
    @logoFiles.each do |dir|
      ws[:hlf].append_text( dir)
    end

    tbl.attach( ws[:hlf], 1, 2, y, y+1, *@tblarg )

    ##############
    y = 3
    label = Gtk::Label.new("CM logoファイル名")
    tbl.attach( label, 0, 1, y, y+1, *@tblarg )

    ws[:clf] = Gtk::ComboBox.new
    n = ( @logoFiles.size / 25 ).to_i + 1
    ws[:clf].wrap_width = n
    @logoFiles.each do |dir|
      ws[:clf].append_text( dir)
    end
    tbl.attach( ws[:clf], 1, 2, y, y+1, *@tblarg )

    ##############
    y = 4
    label = Gtk::Label.new("logo 位置")
    tbl.attach( label, 0, 1, y, y+1, *@tblarg )
    hbox = Gtk::HBox.new(false, 0)
    tbl.attach( hbox, 1, 2, y, y+1, *@tblarg )

    ws[:lp_tl] = Gtk::RadioButton.new("左上")
    ws[:lp_tl].active = true
    hbox.pack_start(ws[:lp_tl], true, true, 0)
    ws[:lp_tr] = Gtk::RadioButton.new(ws[:lp_tl], "右上")
    hbox.pack_start(ws[:lp_tr], true, true, 0)
    ws[:lp_br] = Gtk::RadioButton.new(ws[:lp_tl], "右下")
    hbox.pack_start(ws[:lp_br], true, true, 0)
    ws[:lp_bl] = Gtk::RadioButton.new(ws[:lp_tl], "左下")
    hbox.pack_start(ws[:lp_bl], true, true, 0)

    ##############

    y = 5
    label = Gtk::Label.new("")
    tbl.attach( label, 0, 1, y, y+1, *@tblarg )
    label = Gtk::Label.new("チャプター数")
    tbl.attach( label, 0, 1, y+1, y+2, *@tblarg )
    label = Gtk::Label.new("時間(秒)")
    tbl.attach( label, 0, 1, y+2, y+3, *@tblarg )

    tbl2 = Gtk::Table.new(3, 10, false)
    tbl.attach( tbl2, 1, 2, y, y+3, *@tblarg )

    w = 60
    ws[:cs] = []
    ws[:dr] = []
    DuraN.times.each do |n|
      label = Gtk::Label.new("No. #{n+1}")
      tbl2.attach( label, n, n+1, 0, 1, *@tblarg )
      ws[:cs][n] = Gtk::Entry.new
      ws[:cs][n].set_size_request(w, -1)
      ws[:cs][n].set_xalign(1)
      tbl2.attach( ws[:cs][n], n, n+1, 1, 2, *@tblarg )
      ws[:dr][n] = Gtk::Entry.new
      ws[:dr][n].set_size_request(w, -1)
      ws[:dr][n].set_xalign(1)
      tbl2.attach( ws[:dr][n], n, n+1, 2, 3, *@tblarg )
    end

    ##############
    y = 8
    label = Gtk::Label.new("オプション")
    tbl.attach( label, 0, 1, y, y+1, *@tblarg )
    tbl3 = Gtk::Table.new(3, 12, false)
    tbl.attach( tbl3, 1, 2, y, y+1, *@tblarg )

    y = 0
    
    ###
    y += 1
    label = " CMカット処理は行わず、丸ごと mp4 エンコードする"
    ws[:opt_cs] = Gtk::CheckButton.new( label )
    tbl3.attach( ws[:opt_cs], 0, 2, y, y+1, *@tblarg )

    # ###
    # y += 1
    # label = " cmcuterChk の対象外とする"
    # ws[:opt_ic] = Gtk::CheckButton.new( label )
    # tbl3.attach( ws[:opt_ic], 0, 2, y, y+1, *@tblarg )


    # ###
    # y += 1
    # label = " logo解析は行わず音声データのみでチャプター分割を行う"
    # ws[:opt_au] = Gtk::CheckButton.new( label )
    # tbl3.attach( ws[:opt_au], 0, 2, y, y+1, *@tblarg )

    # ###
    # y += 1
    # label = " EndCard 検出を無効化"
    # ws[:opt_ec] = Gtk::CheckButton.new( label )
    # tbl3.attach( ws[:opt_ec], 0, 2, y, y+1, *@tblarg )

    ###
    y += 1
    hbox = Gtk::HBox.new( false )

    label0 = " 本編途中にCMが無く、本編前後に無音期間がある ( "
    ws[:opt_nhk] = Gtk::CheckButton.new( label0 )
    label1 = Gtk::Label.new("検出する無音期間")
    ws[:opt_termstime] = Gtk::Entry.new
    ws[:opt_termstime].set_size_request(50, -1)
    ws[:opt_termstime].set_xalign(1)
    label2 = Gtk::Label.new("秒以上 )")

    hbox.pack_start(ws[:opt_nhk], false, false, 0)
    hbox.pack_start(label1 , false, false, 0)
    hbox.pack_start(ws[:opt_termstime], false, true, 0)
    hbox.pack_start(label2, false, false, 5)

    tbl3.attach( hbox , 0, 3, y, y+1, *@tblarg )

    ###
    y += 1
    label = " 接合部にフェードアウトを挿入する"
    ws[:opt_fadeout] = Gtk::CheckButton.new( label )
    tbl3.attach( ws[:opt_fadeout], 0, 2, y, y+1, *@tblarg )

    ###
    y += 1
    label = " CMの中から提供候補を探して印を付ける"
    ws[:opt_sponsor_search] = Gtk::CheckButton.new( label )
    tbl3.attach( ws[:opt_sponsor_search], 0, 2, y, y+1, *@tblarg )

    ###
    y += 1
    hbox = Gtk::HBox.new(false, 0)

    label1 = Gtk::Label.new("２カ国語放送")
    hbox.pack_start( label1, false, true, 10)

    label = "そのまま"
    ws[:opt_mono0] = Gtk::RadioButton.new( label )
    hbox.pack_start(ws[:opt_mono0], true, true, 0)

    label = "ステレオの左を残す"
    ws[:opt_mono1] = Gtk::RadioButton.new(ws[:opt_mono0], label )
    hbox.pack_start(ws[:opt_mono1], true, true, 0)

    label = "ストリーム 0 を残す"
    ws[:opt_mono2] = Gtk::RadioButton.new(ws[:opt_mono0], label )
    hbox.pack_start(ws[:opt_mono2], true, true, 0)

    tbl3.attach( hbox, 0, 2, y, y+1, *@tblarg )

    ###
    # y += 1
    # hbox = Gtk::HBox.new( false )
    # label0 = " delogo によるロゴ消し ( "
    # ws[:opt_delogo] = Gtk::CheckButton.new( label0 )
    # hbox.pack_start( ws[:opt_delogo], false, false, 0)

    # label1 = Gtk::Label.new("座標(x=XXX:y=YY:w=WW:h=HH)")
    # hbox.pack_start(label1, false, false, 0)
    # ws[:opt_delogo_pos] = Gtk::Entry.new
    # ws[:opt_delogo_pos].set_size_request(200, -1)

    # hbox.pack_start(ws[:opt_delogo_pos], false, true, 0)

    # label2 = Gtk::Label.new( " ) " )
    # hbox.pack_start(label2, false, false, 0)

    # tbl3.attach( hbox, 0, 1, y, y+1, *@tblarg )


    ###
    y += 1
    hbox = Gtk::HBox.new( false )
    label1 = Gtk::Label.new("n秒のセクションを強制的にCM にする  ")
    hbox.pack_start( label1, false, true, 10)
    @cmTime.each do |time|
      sym = cmTime2sym( time )
      label  = sprintf("%d秒",time)
      ws[sym] = Gtk::CheckButton.new( label )
      hbox.pack_start(ws[sym], false, true, 2)
    end
    tbl3.attach( hbox, 0, 3, y, y+1, *@tblarg )
    
    ###
    y += 1
    hbox = Gtk::HBox.new( false )
    label = Gtk::Label.new("インタレース解除")
    hbox.pack_start(label, false, true, 10)
    ws[:deInterlace] = Gtk::ComboBox.new
    n = ( DeInterlaceList.size / 25 ).to_i + 1
    ws[:deInterlace].wrap_width = n
    DeInterlaceList.each do |str|
      str = NoInterlace if str == ""
      ws[:deInterlace].append_text( str)
    end
    hbox.pack_start(ws[:deInterlace], false, true, 10)

    tbl3.attach( hbox, 0, 1, y, y+1, *@tblarg )
    
    ###
    y += 1
    hbox = Gtk::HBox.new( false )
    label = Gtk::Label.new("ffmpeg vfopt")
    hbox.pack_start(label, false, true, 10)
    ws[:opt_vfopt] = Gtk::Entry.new
    ws[:opt_vfopt].set_size_request(400, -1)
    hbox.pack_start(ws[:opt_vfopt], false, true, 10)

    tbl3.attach( hbox, 0, 1, y, y+1, *@tblarg )
    
    # ###
    y += 1
    hbox = Gtk::HBox.new( false )
    label = Gtk::Label.new("mp4 エンコード用シェルスクリプトの指定")
    hbox.pack_start(label, false, true, 10)
    ws[:tomp4] = Gtk::ComboBox.new
    n = ( @shellFiles.size / 25 ).to_i + 1
    ws[:tomp4].wrap_width = n
    @shellFiles.each do |dir|
      ws[:tomp4].append_text( dir)
    end
    hbox.pack_start(ws[:tomp4], false, true, 10)
    
    tbl3.attach( hbox, 0, 2, y, y+1, *@tblarg )
    # ###
    y += 1
    label = " 本編直後にある 10秒のセクションは提供とみなす"
    ws[:opt_sponor_10sec] = Gtk::CheckButton.new( label )
    tbl3.attach( ws[:opt_sponor_10sec], 0, 2, y, y+1, *@tblarg )


    # ###
    y += 1
    label = " 前処理でコンテナ変換を行う(TSファイルがseek できない場合に使用)"
    ws[:opt_containerConv] = Gtk::CheckButton.new( label )
    tbl3.attach( ws[:opt_containerConv], 0, 2, y, y+1, *@tblarg )


    ###
    y += 1
    hbox = Gtk::HBox.new( false )
    label = Gtk::Label.new("字幕のタイミング調整")
    hbox.pack_start(label, false, true, 10)
    ws[:opt_subadj] = Gtk::Entry.new
    ws[:opt_subadj].set_size_request(50, -1)
    ws[:opt_subadj].set_xalign(1)
    hbox.pack_start(ws[:opt_subadj], false, true, 10)
    label = Gtk::Label.new("秒")
    hbox.pack_start(label, false, true, 0)
    tbl3.attach( hbox, 0, 1, y, y+1, *@tblarg )

    ###
    y += 1
    label = " このディレクトリは無視する"
    ws[:opt_id] = Gtk::CheckButton.new( label )
    tbl3.attach( ws[:opt_id], 0, 2, y, y+1, *@tblarg )

    
    #
    #  コマンドボタン
    #
    hbox = Gtk::HBox.new( true, 200 )

    bon1 = Gtk::Button.new("保存")
    hbox.pack_start(bon1, true, true, 20)
    bon1.signal_connect("clicked") do
      dir = ws[:dir].active_text
      save( ws, dir )
    end


    bon3 = Gtk::Button.new("閉じる")
    hbox.pack_start(bon3, true, true, 20)
    bon3.signal_connect("clicked") do
      window.destroy
      Gtk.main_quit
    end

    ##############

    vbox1.pack_start(tbl, false, false, 10)
    hsep = Gtk::HSeparator.new
    vbox1.pack_start(hsep, false, true, 5)
    vbox1.pack_start(hbox, false, true, 5)


    if @opt[:dir] != nil
      dir = @opt[:dir]
      if ( n = dirs.index( dir )) != nil 
        ws[:dir].set_active(n)
        set_val( ws, dir )
      end
    end

    window.show_all

    Gtk.main
  end
end
