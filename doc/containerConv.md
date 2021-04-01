
## 名前

containerConv.rb - mpeg2-ts からコンテナの変換を行う。

## 書式

containerConv.rb [オプション] TSファイル

## 説明

まれにツールが異常終了してしまう TS ファイルが発生する。
その場合にコンテナ変換をすると解決する事があるので、
containerConv.rb を使って mpeg2-ts のコンテナ変換を行う。
なおコンテナ変換のみなので中身のコーデックは mpeg2video のままである。

 - --mp4

      mp4コンテナに変換する。(デフォルト)
      出力ファイルの拡張子は mp4

 - --ts 

      mpeg2-ts に変換する。
      出力ファイルの拡張子は ts2
  
 - --ps

      mpeg2-ps に変換する。
      出力ファイルの拡張子は ps


 - --link
 
  元ファイルをリネームして、変換後ファイルへの link を作成





## 実行例 

```
% containerConv.rb --mp4 --link test.ts
...
% ls -l 
合計 41112
drwxrwxr-x  2 xxxxxx xxxxxx      100  3月 30 13:00 .
drwxrwxrwt 24 root   root        740  3月 30 13:00 ..
-rw-rw-r--  1 xxxxxx xxxxxx 18412128  3月 30 13:00 test.mp4
lrwxrwxrwx  1 xxxxxx xxxxxx        8  3月 30 13:00 test.ts -> test.mp4
-rw-rw-r--  1 xxxxxx xxxxxx 23680292  3月 30 13:00 test.ts.org


```
