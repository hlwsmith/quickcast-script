# quickcast-script

This is a bash shell script that helps with ffmpeg command line
invocation. It can save a screencast to a file or make a livecast to
YouTube.com or Twitch.tv. Very rough around the edges but perhaps the
source would be useful to others trying to figure out how to use
ffmpeg to stream live content.

I'll put some more info here eventually ;-)

-- Harvey Smith

## random notes follow:
### Some of my webcam's native resolutions

 see: ffmpeg -f v4l2 -list_formats all -i /dev/video0

also see: v4l2-ctl --list-formats-ext

#### 17x9 (1.888)

176x144 30

544x288 30

#### 1.818:

320x176 30

#### 1.80769230769

752x416 30

#### 1.80487804878

1184x656 15

#### 1.80: 9x5 18x10

432x240 30

864x480 24.000

#### 1.78571428571

800x448 30 

#### 1.7778: 16x9

640x360 30

1024x576 15 

1280x720 10

1792x1008 5

1920x1080 5

#### 1.76470588235

960x544 20

#### 1.333: 4x3 12x9 ‘vga’

160x120 ‘qqvga’ 30

320x240 qvga’ 30

640x480 ‘vga’ 30

800x600 ‘svga’ 24

960x720  'DVCpro HD' 15

1280x960  7.5

#### 1.222: 11x9 ‘cif’
  176x144 ‘qcif’
  352x288 ‘cif’

### Common monikers for screen resolutions

‘qqvga’ 160x120 

‘qvga’ 320x240

‘vga’ 640x480

‘svga’ 800x600


‘xga’ 1024x768

‘wvga’ 852x480

‘cga’ 320x200

‘ega’ 640x350


‘hd480’ 852x480 # ‘wvga’

‘hd720’ 1280x720

‘hd1080’ 1920x1080

### other random notes

-set-fmt-video=width=<w>,height=<h>,pixelformat=<f>

v4l2-ctl --get-parm
