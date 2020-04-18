
## 名前

tsSplit.rb - mpeg2ts のファイル分割を行う。

## 書式

tsSplit.rb [オプション] TSファイル

## 説明

TSファイルを 指定した秒数で分割する。 (-t)  
  又は指定した時間の無音期間で分割する ( --sd? )

  - -ｔ n

      秒数指定で、分割を行う。 --sd? とは排他

- --sd1

  無音期間を検出して、そこを分割ポイントとする。 (1pass目)  
  無音期間を変化させて探索するモード
  
- --sd2

 無音期間を検出して、そこを分割ポイントとする。  (2pass目)  
 分割を実行するモード

- -n n

 分割後のナンバリングの開始を n とする。
 デフォルトは 1。

- -m n

 分割開始点に -n秒、分割終了点に +n秒のマージンを持たせる。
 デフォルトは 1.0秒。

- --th n

 検出する無音期間を n 秒とする。
 デフォルトは 5.0秒。





## 実行例 (秒数指定で分割)


```
% tsSplit.rb -t 1800 foo.ts
ffmpeg -loglevel fatal -hide_banner -ss 0 -i foo.ts -t 1801.0 -vcodec copy -acodec copy "foo #01.ts"
3.12 Sec
ffmpeg -loglevel fatal -hide_banner -ss 1799.0 -i foo.ts -t 1801.0 -vcodec copy -acodec copy "foo #02.ts"
10.58 Sec
ffmpeg -loglevel fatal -hide_banner -ss 3599.0 -i foo.ts -t 1801.0 -vcodec copy -acodec copy "foo #03.ts"
0.11 Sec

```

## 実行例 (無音期間検出で分割)

```
% tsSplit.rb --sd1  foo.ts
ffmpeg -loglevel fatal -hide_banner -i foo.ts -vn -ac 1 -ar 4410 -acodec pcm_s16le -f wav -y foo.wav
29.08 Sec

--th = 2.0
  1 0:00:08.88   
  2 0:24:13.79   (0:24:12.83)
  3 0:30:08.80   (0:05:47.16)
  4 0:54:16.21   (0:24:17.71)
  5 0:55:20.70   (0:00:55.06)
  6 1:00:08.87   (0:04:47.24)

…  途中省略 …

--th = 3.5
  1 0:24:13.79   
  2 0:54:16.21   (0:30:04.87)
  3 0:55:20.70   (0:00:55.06)

…  途中省略 …

--th = 5.0
  1 0:24:13.79   
  2 0:54:16.21   (0:30:04.87)

--sd2 と --th X.X を指定して、再度実行して下さい。

% tsSplit.rb --sd2 foo.ts --th 3.5

```
