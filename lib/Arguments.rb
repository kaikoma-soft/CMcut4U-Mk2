# coding: utf-8

require 'optparse'

class Arguments

  attr_reader :config,       # configファイルの指定
              :debug,        # debug
              :indir,        # 処理対象dir
              :outdir,       # 出力Dir
              :workdir,      # 作業用Dir
              :logodir,      # logo Dir
              :appdir,       # App dir
              :ic,           # Ignore check chapList.txt
              :force,        # 自動判定処理の強制実行
              :co,           # 自動判定処理のみで、エンコードしない
              :noCache,      # キャッシュデータを使わない
              :fixgui,       # fixgui の起動
              :chkng,        # チェックが NG のみ表示する。
              :ngFix,        # NG の場合 チャプター修正ダイアログを起動する。
              :regex,        # 処理対象のファイルを正規表現で指定
              :paraedit,     # パラメタファイル編集ダイアログを起動する。
              :viewchk,      # 目視チェックで go/no go を決定
              :tomp4,        # mp4 エンコードするスクリプトの指定
              :ts2mp4,       # TSをmp4に変換する。(debug用)
              :autoremove,   # 作業ディレクトリの自動削除
              :forceEnc,     # 期待値照合の結果を無視してエンコードを実行
              :logo,         # ロコ作成モード
              :empty         # パラメータ設定ファイルが無いものだけを対象
  
  
  def initialize(argv)
    @config  = nil
    @indir   = nil
    @outdir  = nil
    @workdir = nil
    @logodir = nil
    @debug   = false
    @appdir  = nil
    @ic      = true
    @force   = false
    @co      = false
    @noCache = false
    @fixgui  = false
    @chkng   = false
    @ngFix   = false
    @regex   = nil
    @paraedit= false
    @viewchk = false
    @tomp4   = nil
    @ts2mp4  = false
    @autoremove = nil
    @forceEnc = false
    @logo    = false
    @ngpara  = false
    @empty   = false
    
    op = option_parser
    op.parse!(argv)

    pname = File.basename( $0 )
    dir = File.dirname( $0 )
    if test( ?f, dir + "/" + pname )
      @appdir = dir
    else
      ENV["PATH"].split(/:/).each do |dir|
        if test( ?f, dir + "/" + Pname )
          @appdir = dir
          break
        end
      end
    end
    
  rescue OptionParser::ParseError => e
    $stderr.puts e
    exit(1)
  end

  def setConfig()

    if @indir == nil and  Object.const_defined?(:TSdir) == true
      @indir  = TSdir
    end

    if @outdir == nil
      @outdir = Object.const_defined?(:Outdir) == true ? Outdir : "."
    end

    if @workdir == nil
      @workdir = Object.const_defined?(:Workdir) == true ? Workdir : "."
    end

    if @logodir == nil and Object.const_defined?(:LogoDir) == true
      @logodir = LogoDir
    end

    if @autoremove == nil
      @autoremove = Object.const_defined?(:Autoremove) == true ? Autoremove : false
    end
                       
    
  end

  private

  def option_parser
    OptionParser.new do |op|
      op.on('-C file', '--config file ','configファイルの指定') do
        |t| @config = t
      end
      op.on('-R dir','処理対象dirの指定') do
        |t| @indir = t
      end
      op.on('-O dir','--odir dir','出力Dirの指定') do
        |t| @outdir = t
      end
      op.on('-W dir','--wdir dir','作業用Dirの指定') do
        |t| @workdir = t
      end
      op.on('-L dir','--logodir dir','logo Dirの指定') do
        |t| @logodir = t
      end
      op.on('-R','--regex str','処理対象ファイルの指定(正規表現)') do
        |t| @regex = t
      end
      op.on('-d', '--debug', 'debug mode') do
        @debug = !@debug
      end
      op.on('-F', '--force', '自動判定処理の強制実行')  do
        @force = !@force
      end
      op.on('-c', '--co', '自動判定処理のみ') do
        @co = !@co
      end
      op.on('-n', '--nc', 'キャッシュデータを使わない') do
        @noCache = !@noCache
      end
      op.on('-f', '--fix', 'チャプター修正ダイアログの起動') do
        @fixgui = !@fixgui
      end
      op.on( '-n', '--ngfix',
             'chk が NG の時、チャプター修正ダイアログを起動') do
        @ngFix = true
        @co    = true
      end
      op.on( '-p', '--paraedit', 'パラメータ設定ダイヤログを起動') do
        @paraedit = !@paraedit
      end
      op.on('-P', '--emptyPara',
            'パラメータが未設定のものだけパラメータ設定ダイヤログを起動')  do
        @empty = !@empty
      end
      op.on( '-v', '--viewchk', '目視チェックで go/no go を決定') do
        @viewchk = !@viewchk
      end
      op.on( '--tomp4 shell', 'mp4 エンコードするスクリプトの指定') do
        |v| @tomp4 = v
      end
      op.on( '--ts2mp4', 'TSをmp4に変換する。(debug用)') do
        @ts2mp4 = !@ts2mp4
      end
      op.on( '-a', '--autoremove', '作業ディレクトリの自動削除') do
        @autoremove = !@autoremove
      end
      op.on('-E','--forceEnc', '期待値照合の結果を無視してエンコードを実行') do
        @forceEnc = !@forceEnc
      end
      op.on('-l','--logo', 'ロゴ作成モード') do
        @logo = !@logo
      end

      op.program_name = Pname
      op.version      = Version
      op.release      = Release
    end
  end

end
