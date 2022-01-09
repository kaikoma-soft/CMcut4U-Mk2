#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-
#

#
#   定数定義
#
Top       = ENV["HOME"] + "/video"

FFMPEG_BIN  = "/usr/bin/X11/ffmpeg"
PYTHON_BIN  = "/usr/bin/python2"

NomalSize   = "1280x720"
CMSize      = "640x360"
ToMp4       = "to_mp4.sh"
FixguiPosition = { x: 50, y: 100 }

#
#  mpv オプション
#
Mpv_opt = %w( --osd-duration=3000 --osd-level=2 --really-quiet -geometry +840+154 --autofit=720x405  )

#
#  インタレース削除
#
DeInterlaceList = [ "",
                    "yadif=0:-1:1",
                    "yadif=0:-1:1,decimate,setpts=N/(24000/1001)/TB",
                    "w3fdif=1:0",
                    "bwdif=0:-1:0",
                  ]
DefaultDeInterlace = "yadif=0:-1:1"

DelTSZero   = true    # TSファイル削除時に、0byte のファイルを残すか(true=残す)
FadeOut     = false   # チャプターの継ぎ目にFadeOutを挿入するかのデフォルト値(ture=する)
FadeOutTime = 0.5     # FadeOut の時間(秒)
Autoremove  = true    # 最後に作業ディレクトリの自動削除を行うか(ture=する)
TsExpireDay = 3       # TSファイルをゴミ箱に移動した後、何日で削除するか(日)
FrontMargin = 1       # チャプターを打つタイミングとの継ぎ目のマージン(秒)
Subtitling  = false   # 字幕の処理を行うか(true=行う)
ForceCmTime = [ 3, 5, 10, 15, 20, 30, 50, 60, 90 ] # 強制的にCMする秒数の候補


TSdir       = Top + "/TS"
Outdir      = Top + "/mp4"
Trashdir    = Top + "/TrashBox"
LogoDir     = Top + "/logo"
Workdir     = Top + "/work"
LockFile    = Workdir + "/.lock"

#
#  ロゴ消し
#
RmLogoDir   = Top + "/rmlogo"
RmLogoBlurList = {
  :null      => "null",                        # 素通し
  :avgblur   => "avgblur=3:15:3",
  :gblur     => "gblur=2:4:15:-1",
  :smartblur1 => "smartblur=1:1:0:1:1:0",
  :smartblur2 => "smartblur=2:1:0:2:1:0",
  :unsharp1   => "unsharp=5:5:-1.0:5:5:-1.0",
  :unsharp2   => "unsharp=7:7:-1.5:7:7:-1.5",
  }
RmLogoBlurDefault = :unsharp1
