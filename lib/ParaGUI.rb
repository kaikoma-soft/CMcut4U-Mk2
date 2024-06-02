#!/usr/bin/ruby
# -*- coding: utf-8 -*-

#
#  para.yaml の編集 GUI
#

require 'gtk3'

class ParaGUI

  DuraN  = 10                   # duration の設定数
  LogoNotUseTxt = "使用しない (丸ごと１本 or 音声のみで処理する or CM)"
  RmLogoNotUseTxt = "使用しない"
  NoInterlace   = "しない"

  def set_margin( w, t, r, b , l )
    w.set_margin_top( t )
    w.set_margin_left( l )
    w.set_margin_right( r )
    w.set_margin_bottom( b )
  end
  
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

    @logoFiles =  listLogoDir( LogoDir )
    @logoFiles << LogoNotUseTxt

    @rmlogoFiles = [ RmLogoNotUseTxt ]
    if RmLogoDir != nil
      listLogoDir( RmLogoDir ).each do |fn|
        @rmlogoFiles << fn if fn =~ /(\d+)x(\d+)\+(\d+)\+(\d+)\./
      end
    end
    @shellFiles = listShells()

    Signal.trap( :INT ) { exit() }
    #tblarg = [ Gtk::FILL,Gtk::EXPAND, 2, 2 ]
    ws = {}

    #
    #  GUI 作成
    #
    window = Gtk::Window.new
    window.name = "main window"

    window.set_default_size(600, 300)
    window.signal_connect("destroy"){ Gtk.main_quit  }

    # vbox1
    @vbox1 = Gtk::Box.new(:vertical, 5 )
    window.add(@vbox1)

    tbl = Gtk::Grid.new()
    tbl.row_spacing    = 5
    tbl.column_spacing = 5
    set_margin( tbl, 10, 5, 5, 5 )
    @gridW = 6
    
    ##############
    y = 0
    label = Gtk::Label.new("対象ディレクトリ")
    tbl.attach( label, 0, 0, 1, 1 )

    ws[:dir] = Gtk::ComboBoxText.new
    n = ( dirs.size / 25 ).to_i + 1
    ws[:dir].wrap_width = n
    dirs.each_with_index do |dir,n|
      dir.sub!(/#{$opt.indir}\//,'')
      ws[:dir].append_text( dir )
      if dir == @opt[:dir]
        ws[:dir].set_active(n)
      end
    end
    tbl.attach( ws[:dir], 1, 0, @gridW, 1 )

    ws[:dir].signal_connect("changed") do |widget|
      dir = widget.active_text
      set_val( ws, dir )
    end

    ##############
    y += 1
    hsep = Gtk::Separator.new(:horizontal)
    tbl.attach( hsep, 0, y, @gridW, 1)

    ##############
    y += 1
    label = Gtk::Label.new("本編 logoファイル名")
    tbl.attach( label, 0, y, 1, 1)

    ws[:hlf] = Gtk::ComboBoxText.new
    n = ( @logoFiles.size / 25 ).to_i + 1
    ws[:hlf].wrap_width = n
    @logoFiles.each do |dir|
      ws[:hlf].append_text( dir)
    end

    tbl.attach( ws[:hlf], 1, y, @gridW, 1 )

    ##############
    y += 1
    label = Gtk::Label.new("CM logoファイル名")
    tbl.attach( label, 0, y, 1, 1 )

    ws[:clf] = Gtk::ComboBoxText.new
    n = ( @logoFiles.size / 25 ).to_i + 1
    ws[:clf].wrap_width = n
    @logoFiles.each do |dir|
      ws[:clf].append_text( dir)
    end
    tbl.attach( ws[:clf], 1, y, @gridW, 1 )

    ##############
    y += 1
    label = Gtk::Label.new("logo 位置")
    tbl.attach( label, 0, y, 1, 1 )
    hbox = Gtk::Box.new(:horizontal, 0 )
    tbl.attach( hbox, 1, y, @gridW, 1 )

    ws[:lp_tl] = Gtk::RadioButton.new( :label => "左上")
    ws[:lp_tl].active = true
    hbox.pack_start(ws[:lp_tl], :expand => true, :fill => true, :padding => 0)
    ws[:lp_tr] = Gtk::RadioButton.new( :member => ws[:lp_tl], :label => "右上")
    hbox.pack_start(ws[:lp_tr], :expand => true, :fill => true, :padding => 0)
    ws[:lp_br] = Gtk::RadioButton.new( :member => ws[:lp_tl], :label => "右下")
    hbox.pack_start(ws[:lp_br], :expand => true, :fill => true, :padding => 0)
    ws[:lp_bl] = Gtk::RadioButton.new( :member => ws[:lp_tl], :label => "左下")
    hbox.pack_start(ws[:lp_bl], :expand => true, :fill => true, :padding => 0)

    ##############
    y += 1
    
    tbl2 = Gtk::Grid.new()
    tbl2.row_spacing    = 4
    tbl2.column_spacing = 4
    set_margin( tbl2, 10, 10, 5, 10 )
    tbl2.set_size_request( 400, -1)
    
    label = Gtk::Label.new(" ")
    tbl2.attach( label, 0, 0, 1, 1 )
    label = Gtk::Label.new("チャプター数")
    tbl2.attach( label, 0, 1, 1, 1)
    label = Gtk::Label.new("時間(秒)")
    tbl2.attach( label, 0, 2, 1, 1 )

    tmp = frame = Gtk::Frame.new("本編のチャプター数、時間の期待値")
    set_margin( tmp, 10, 10, 5, 10 )
    frame.add(tbl2)
    tbl.attach( frame, 0, y, @gridW +1, 1 )

    w = 5
    ws[:cs] = []
    ws[:dr] = []

    DuraN.times.each do |n|
      label = Gtk::Label.new("No. #{n+1}")
      label.set_size_request(w, -1)
      label.set_hexpand( false )
      tbl2.attach( label, n+1, 0, 1, 1 )
      tmp = ws[:cs][n] = Gtk::Entry.new
      tmp.set_xalign(1)
      tmp.set_width_chars(w)
      tbl2.attach( tmp, n+1, 1, 1, 1)
      tmp = ws[:dr][n] = Gtk::Entry.new
      tmp.set_xalign(1)
      tmp.set_width_chars(w)
      tbl2.attach( ws[:dr][n], n+1, 2, 1, 1 )
    end

    ############## オプション
    y += 1
    tmp = frame = Gtk::Frame.new("オプション")
    set_margin( tmp, 10, 10, 0, 10 )
    tmp = optvbox = Gtk::Box.new(:vertical, 1 )
    set_margin( tmp, 10, 10, 10, 10 )
    frame.add(optvbox)
    tbl.attach( frame, 0, y, @gridW+1, 1 )

    ###
    label = " CMカット処理は行わず、丸ごと mp4 エンコードする"
    ws[:opt_cs] = Gtk::CheckButton.new( label )
    optvbox.pack_start(ws[:opt_cs], :expand => false, :fill => false, :padding => 1 )

    ###
    hbox = Gtk::Box.new(:horizontal, 0 )

    label0 = " 本編途中にCMが無く、本編前後に無音期間がある ( "
    ws[:opt_nhk] = Gtk::CheckButton.new( label0 )
    label1 = Gtk::Label.new("検出する無音期間")
    ws[:opt_termstime] = Gtk::Entry.new
    ws[:opt_termstime].set_size_request(50, -1)
    ws[:opt_termstime].set_xalign(1)
    label2 = Gtk::Label.new("秒以上 )")

    hbox.pack_start(ws[:opt_nhk], :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(label1, :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(ws[:opt_termstime], :expand => false, :fill => true, :padding => 0)
    hbox.pack_start(label2, :expand => false, :fill => false, :padding => 5)

    optvbox.pack_start(hbox, :expand => false, :fill => false, :padding => 1 )

    ###
    label = " 接合部にフェードアウトを挿入する"
    ws[:opt_fadeout] = Gtk::CheckButton.new( label )
    optvbox.pack_start(ws[:opt_fadeout], :expand => false, :fill => false, :padding => 1 )

    ###
    label = " CMの中から提供候補を探して印を付ける"
    ws[:opt_sponsor_search] = Gtk::CheckButton.new( label )
    optvbox.pack_start(ws[:opt_sponsor_search], :expand => false, :fill => false, :padding => 1 )

    ###
    hbox = Gtk::Box.new(:horizontal, 0 )

    label1 = Gtk::Label.new("２カ国語放送")
    hbox.pack_start( label1, :expand => false, :fill => true, :padding => 10)

    label = "そのまま"
    ws[:opt_mono0] = Gtk::RadioButton.new( :label => label )
    hbox.pack_start(ws[:opt_mono0], :expand => true, :fill => true, :padding => 0)

    label = "ステレオの左を残す"
    ws[:opt_mono1] = Gtk::RadioButton.new( :member => ws[:opt_mono0], :label => label )
    hbox.pack_start(ws[:opt_mono1], :expand => true, :fill => true, :padding => 0)

    label = "ストリーム 0 を残す"
    ws[:opt_mono2] = Gtk::RadioButton.new(:member =>  ws[:opt_mono0], :label => label )
    hbox.pack_start(ws[:opt_mono2], :expand => true, :fill => true, :padding => 0)

    optvbox.pack_start(hbox, :expand => false, :fill => false, :padding => 1 )

    ###
    hbox = Gtk::Box.new(:horizontal, 0 )
    label1 = Gtk::Label.new("n秒のセクションを強制的にCM にする  ")
    hbox.pack_start( label1, :expand => false, :fill => true, :padding => 10)
    @cmTime.each do |time|
      sym = cmTime2sym( time )
      label  = sprintf("%d秒",time)
      ws[sym] = Gtk::CheckButton.new( label )
      hbox.pack_start( ws[sym], :expand => false, :fill => true, :padding => 2)
    end
    optvbox.pack_start(hbox, :expand => false, :fill => false, :padding => 1 )
    
    ###
    hbox = Gtk::Box.new(:horizontal, 0 )
    label = Gtk::Label.new("インタレース解除")
    hbox.pack_start(label, :expand => false, :fill => true, :padding => 10 )
    ws[:deInterlace] = Gtk::ComboBoxText.new
    n = ( DeInterlaceList.size / 25 ).to_i + 1
    ws[:deInterlace].wrap_width = n
    DeInterlaceList.each do |str|
      str = NoInterlace if str == ""
      ws[:deInterlace].append_text( str)
    end
    hbox.pack_start(ws[:deInterlace], :expand => false, :fill => true, :padding => 10 )
    optvbox.pack_start(hbox, :expand => false, :fill => false, :padding => 1 )
    
    ###
    hbox = Gtk::Box.new(:horizontal, 0 )
    label = Gtk::Label.new("ffmpeg vfopt")
    hbox.pack_start(label, :expand => false, :fill => true, :padding => 10 )
    ws[:opt_vfopt] = Gtk::Entry.new
    ws[:opt_vfopt].set_size_request(400, -1)
    hbox.pack_start(ws[:opt_vfopt], :expand => false, :fill => true, :padding => 10 )

    optvbox.pack_start(hbox, :expand => false, :fill => false, :padding => 1 )
    
    # ###
    hbox = Gtk::Box.new(:horizontal, 0 )
    label = Gtk::Label.new("mp4 エンコード用シェルスクリプトの指定")
    hbox.pack_start(label, :expand => false, :fill => true, :padding => 10 )
    ws[:tomp4] = Gtk::ComboBoxText.new
    n = ( @shellFiles.size / 25 ).to_i + 1
    ws[:tomp4].wrap_width = n
    @shellFiles.each do |dir|
      ws[:tomp4].append_text( dir)
    end
    hbox.pack_start(ws[:tomp4], :expand => false, :fill => true, :padding => 10 )
    
    optvbox.pack_start(hbox, :expand => false, :fill => false, :padding => 1 )

    # ###
    label = " 本編直後にある 10秒のセクションは提供とみなす"
    tmp = ws[:opt_sponor_10sec] = Gtk::CheckButton.new( label )
    optvbox.pack_start( tmp, :expand => false, :fill => false, :padding => 1 )

    # ###
    y += 1
    label = " 前処理でコンテナ変換を行う(TSファイルがseek できない場合に使用)"
    tmp = ws[:opt_containerConv] = Gtk::CheckButton.new( label )
    optvbox.pack_start( tmp, :expand => false, :fill => false, :padding => 1 )

    ###
    hbox = Gtk::Box.new(:horizontal, 0 )
    label = Gtk::Label.new("字幕のタイミング調整")
    hbox.pack_start(label, :expand => false, :fill => true, :padding => 10 )
    ws[:opt_subadj] = Gtk::Entry.new
    ws[:opt_subadj].set_size_request(50, -1)
    ws[:opt_subadj].set_xalign(1)
    hbox.pack_start(ws[:opt_subadj], :expand => false, :fill => true, :padding => 10 )
    label = Gtk::Label.new("秒")
    hbox.pack_start(label, :expand => false, :fill => true, :padding => 0 )

    optvbox.pack_start( hbox, :expand => false, :fill => false, :padding => 1 )

    ###
    hbox = Gtk::Box.new(:horizontal, 0 )
    label = Gtk::Label.new("ロゴ除去 マスクファイル名")
    hbox.pack_start(label, :expand => false, :fill => true, :padding => 10 )

    ws[:rmlogo] = Gtk::ComboBoxText.new
    n = ( @rmlogoFiles.size / 25 ).to_i + 1
    ws[:rmlogo].wrap_width = n
    @rmlogoFiles.each do |dir|
      ws[:rmlogo].append_text(dir)
    end
    hbox.pack_start(ws[:rmlogo], :expand => false, :fill => true, :padding => 10 )
    
    optvbox.pack_start( hbox, :expand => false, :fill => false, :padding => 1 )
    
    ###
    hbox = Gtk::Box.new(:horizontal, 0 )
    label = Gtk::Label.new("ロゴ除去 ぼかしフィルター")
    hbox.pack_start(label, :expand => false, :fill => true, :padding => 10 )

    ws[:rmlogo_blur] = Gtk::ComboBoxText.new
    n = ( RmLogoBlurList.size / 25 ).to_i + 1
    ws[:rmlogo_blur].wrap_width = n
    RmLogoBlurList.each_pair do |k,v|
      v = "使用しない" if v == "null"
      ws[:rmlogo_blur].append_text(v)
    end
    hbox.pack_start(ws[:rmlogo_blur], :expand => false, :fill => true, :padding => 10 )
    
    optvbox.pack_start( hbox, :expand => false, :fill => false, :padding => 1 )
    
    ###
    label = " ロゴを検出した時だけロゴ除去フィルターを掛ける"
    tmp = ws[:opt_rmlogo_detect] = Gtk::CheckButton.new( label )
    optvbox.pack_start( tmp, :expand => false, :fill => false, :padding => 1 )

    # ロゴ除去関連の連動
    ws[:rmlogo].signal_connect("changed") do |widget|
      maskfn = ws[:rmlogo].active_text
      sw =  maskfn == RmLogoNotUseTxt ? false : true
      ws[:opt_rmlogo_detect].set_sensitive( sw )
      ws[:rmlogo_blur].set_sensitive( sw )
    end
    
    ###
    label = " このディレクトリは無視する"
    tmp = ws[:opt_id] = Gtk::CheckButton.new( label )
    optvbox.pack_start( tmp, :expand => false, :fill => false, :padding => 1 )

    #
    #  コマンドボタン
    #
    hbox = Gtk::Box.new(:horizontal, 200 )

    bon1 = Gtk::Button.new( :label => "保存")
    hbox.pack_start(bon1, :expand => true, :fill => true, :padding => 20 )
    bon1.signal_connect("clicked") do
      dir = ws[:dir].active_text
      save( ws, dir )
    end

    bon3 = Gtk::Button.new( :label => "閉じる")
    hbox.pack_start(bon3, :expand => true, :fill => true, :padding => 20 )
    bon3.signal_connect("clicked") do
      window.destroy
      Gtk.main_quit
    end

    ##############

    @vbox1.pack_start(tbl, :expand => false, :fill => false, :padding => 0 )
    hsep = Gtk::Separator.new(:horizontal)
    @vbox1.pack_start(hsep, :expand => false, :fill => true, :padding => 5 )
    @vbox1.pack_start(hbox, :expand => false, :fill => true, :padding => 5 )

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
