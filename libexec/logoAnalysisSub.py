#!/usr/bin/env python
# -*- coding: utf-8 -*-

#
#  opencv テンプレートマッチで、logo の有無を判定する。
#

import cv2 as cv
import os
import sys
from pprint import pprint
import argparse

delay = 0                       # 画像表示の wait時間
th = 0.5                        # 閾値
path="."                        # png 格納dir

parser = argparse.ArgumentParser()
parser.add_argument("--logo",action='append',help="logo file name",type=str)
parser.add_argument("--dir",help="screenshot png dir",type=str)
parser.add_argument("--delay",help="wait time",type=int,default=0)
parser.add_argument("--th",help="Threshold",type=float,default=0)
parser.add_argument("-d",action='store_true',default=False,help="debug flag")
parser.add_argument("-c",action='store_true',default=False,help="color mode")
args = parser.parse_args()


def info( img ):
    if len(img.shape) == 3:
        height, width, channels = img.shape[:3]
    else:
        height, width = img.shape[:2]
        channels = 1

    # 取得結果（幅，高さ，チャンネル数，depth）を表示
    print("width: " + str(width))
    print("height: " + str(height))
    print("channels: " + str(channels))
    print("dtype: " + str(img.dtype))


def getChannels( img ):
    if len(img.shape) == 3:
        height, width, channels = img.shape[:3]
    else:
        height, width = img.shape[:2]
        channels = 1
    return channels
    
colorMode = False

if(args.dir != None ):
    path = args.dir

if(args.delay != 0 ):
    delay = args.delay

if(args.th != 0):
    th = args.th
    #print("th = " + str(th))
    
print("logo: " + str(args.logo))
temps = []
if( args.logo != None ):
    for logofname in args.logo :
        temp = cv.imread( logofname, -1)
        temps.append( temp )
        #info( temp )
        channels = getChannels( temp ) 
        if ( channels != 1 ):
            colorMode = True
            th = 0.6
        print("# file={0} Channels={1}".format(logofname, channels))
        
files = sorted(os.listdir(path))
n = 0
while n < len(files):
    
    x = files[ n ]
    if(x[-4:] == '.png' or x[-4:] == '.jpg'):

        imgfn = path + "/" + x

        img = cv.imread(imgfn)
        if ( colorMode == False ):
            img_gray = cv.cvtColor(img, cv.COLOR_RGB2GRAY)
            #img_gray = cv.GaussianBlur(img_gray, (3, 3), 0)

            img_sobel_x = cv.Sobel(img_gray, cv.CV_32F, 1, 0)
            img_sobel_y = cv.Sobel(img_gray, cv.CV_32F, 0, 1)
            img_sobel_x = cv.convertScaleAbs(img_sobel_x)
            img_sobel_y = cv.convertScaleAbs(img_sobel_y)
            imgg = cv.addWeighted(img_sobel_x, 0.5, img_sobel_y, 0.5, 0)
        else:
            imgg = img
            
        if(args.logo != None ):
            #マッチングテンプレートを実行
            logo = 0
            val = 0
            for temp in temps:
                result = cv.matchTemplate(imgg, temp, cv.TM_CCOEFF_NORMED)

                #検出結果から検出領域の位置を取得
                min_val, max_val, min_loc, max_loc = cv.minMaxLoc(result)

                if( max_val > th ):
                    logo = 1
                    break
                if ( max_val > val ): val = max_val 
                
            print("{0} {1:.3f} {2}".format(x, val,logo))
        else:
            print("{0}".format(x))

        if ( args.d == True and logo == 1 ) or (args.logo == None ):
            if ( colorMode == False ):
                imgg2 = cv.cvtColor(imgg, cv.COLOR_GRAY2RGB)
            else:
                imgg2 = imgg
            img_v = cv.vconcat([img, imgg2])
            cv.imshow('gray_sobel_edge',img_v)
            key = cv.waitKey(delay) 
            if ( key == 113 ): # q
                cv.destroyAllWindows()
                sys.exit()
            elif ( key == 115 ): # s
                for m in range(9999):
                    fname = 'logo-%04d.png' % m
                    if os.path.exists(fname) == False: break
                    
                cv.imwrite( fname, img_v)
                print "save {0}".format( fname )
            elif ( key == 106 ): # j
                n += 60
            elif ( key == 98 ): # b
                n -= 2
            elif ( key == 107 ): # k
                n -= 61
            
    n += 1
    if( n < 0 ): n = 0 
        
        
