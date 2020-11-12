# coding: utf-8

SilenceTime     = 0.34          # 無音時間の区切りの閾値(秒)
LongSilenceTime = 2.0           # NHKタイプの区切り時間(秒)
TotalGosa       = 2.0           # 期待値照合の許容誤差(秒)
MinSection      = 2.5           # 最小セクション幅 (次回予告で3秒がある)(秒)
SectionGosa     = 0.75          # CMセクションの許容誤差

Fps       = 29.97
WavRatio  = 44100 / 8

# ScreenShot framerate
SS_rate       = 1.0 / 2
SS_frame_rate = 2

Pname   = "CMcut4U2.rb"
Version = "1.0.1"
Release = "2020-11-12"

A_OFF  = :A_off                # 音声：無音
A_ON   = :A_on                 # 音声：音声有り
HON    = :hon                  # 本編
CM     = :cm                   # CM
NONE   = :none                 # なし
LOGO   = :logo                 # logo あり
SOD    = :start                # 開始 Start Of Data
EOD    = :end                  # 終端 End Of Data
  
