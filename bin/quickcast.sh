#!/bin/bash

# if a special ffmpeg is needed and toher variables
#FFMPEG="ffmpeg -loglevel warning"
FFMPEG="ffmpeg -y -loglevel info"
WEBCAM=/dev/video0
DATE=`date +%Y-%m-%d_%H%M%S`
SAVEDIR=${HOME}/streamcasts
# default local filename prefixes
OUTPREFIX=livecast
OUTFILE=${SAVEDIR}/${OUTPREFIX}_${DATE}.mkv
source .quickcast_keys

USAGE="
USAGE: livecast [options] <stream_type>
  Options:
      -h
          Output this help
      -b <Audio bitrate>
          The bitrate for the aac audio codec in kbps. 
          The default is 32**<number of channels> for Twitch streams 
          and 64*<number of channels> for everything else. 
      -c <Audio_channels>
          The number of audio channels 1 (mono) or 2 (stereo.)
           The default is 1 for Twitch streams and 2 for everthing else.
      -f <filename>
          Record local copy to <filename> 
          Defaults to  ${OUTPREFIX}_<date_string>.mkv
          This only setting only applies to YouTube streams. 
          Twitch streams aren't saved locally and the others are always 
          saved locally.
      -g <size>
          Sets the screen grab capture dimensions of the form WIDTHxHEIGHT
          If omitted it is selected interactively via clicking on the 
          desired window for Twitch streams or for Screen captures, and 
          no screen is grabbed for everythihg else. 
      -i <size>
          Size of the input video from the webcam, one of:
            160x120 176x144 352x288 432x240 640x360 864x480 1280x720
          The first three are more square-ish (qqvga, qcif cif), for insets.
          The others are 16x9 (or almost).  If omitted the webcam is not 
          used for Twitch streams or Screen captures and output size 
          is used for everthing else.
      -o <output_height> 
          Sets the output height, where <output_height> is one of:
             240p 360p 450 480p 504 540 576 720p 900 1008 and 1080p
          All are hardcoded 16x9 (except 240p and 480p which are almost 16x9)
          240p, 360p 480p and 720p could be used to live stream to YouTube.
          This overrides any -s option, since they clash.
          If neither -s or -o options are given the default depends are:
          720p for 'camcap', 360p for 'youtube', 1080p for 'screencap'
          and 504 for the 'twitch' and 'twitchcam' streams.
      -r <vrate>
          The video frame rate. If omitted defaults depends on the output
          video size configuration.
      -s <scaled_height>
          Scales the screen grab (or webcam) width and height and scales 
          them down to fit into <height> (maintianing the ratio) and sets 
          the resulting dimensions as the output size. Therefor the output
          likely wont be a neat 16x9 or other common video size ratio.
          Overriden by the -o setting, since they clash.
      -t
          Test run, does not stream, instead saves to: 
            test_<stream_name>.f4v
      -v <v4l2_capture_device>
          If omitted ${WEBCAM} is used.
      -x <X offset>
          The X offset from the left side of the screen of left edge 
          of the screen grab area. If omitted it is selected interactively 
          via clicking on the desired window.
      -y <Y offset>
          The Y offset from the top side of the screen of the top edge
          of the screen grab area. If omitted it is selected interactively 
          via clicking on the desired window.
"
STREAM_TYPES="camcap youtube screencap twitch twitchcam"
declare -A STREAM_DESCS
STREAM_DESCS[camcap]="    - Capture the webcam and save locally."
STREAM_DESCS[youtube]="   - Same as 'camcap' but stream it to YouTube.com too."
STREAM_DESCS[screencap]=" - Grab part of the screen and save locally."
STREAM_DESCS[twitch]="    - Grab part of the screen and stream to Twitch.tv."
STREAM_DESCS[twitchcam]=" - Same as 'twitch' with cam inset at lower left."

set_this_wh ()
{
    WxH=$(echo $1 | sed 's/x/ /')
    THIS_W=$(echo $WxH | awk '{print $1}')
    THIS_H=$(echo $WxH | awk '{print $2}')
}

set_cam_dimensions ()
{
    set_this_wh $1
    v4l2-ctl --set-fmt-video=width=${THIS_W},height=${THIS_H},pixelformat=YUYV
}


set_this ()
# default requested
{
    DEFAULT=${1}
    REQUESTED=${2}
    if [ $REQUESTED ] ; then 
	THIS=${REQUESTED}
    else
	THIS=${DEFAULT}
    fi
}

set_outsize ()
{
# 240p 360p 450 480p 504 540 576 720p 900 1008 and 1080
    case $1 in
	240p)
	    #or half of hd480? at 426x240?
	    OUT_W=432
	    OUT_H=240
	    ;;
	360p)
	    OUT_W=640
	    OUT_H=360
	    ;;
	450) 
	    OUT_W=800
	    OUT_H=450
	    ;; 
	480p)
	    # the 864x480 my logitech cam does? or 852x480 that is hd480?
	    OUT_W=864
	    OUT_H=480
	    ;;
	504) 
	    OUT_W=896
	    OUT_H=504
	    ;; 
	540) 
	    OUT_W=960
	    OUT_H=540
	    ;; 
	576) 
	    # a logitech cam size
	    OUT_W=1024
	    OUT_H=576
	    ;; 
	720p) 
	    # aka hd720
	    OUT_W=1280
	    OUT_H=720
	    ;;
	900) 
	    OUT_W=1600
	    OUT_H=900
	    ;; 
	1008) 
	    OUT_W=1792
	    OUT_H=1008
	    ;; 
	1080p) 
	    # aka hd1080
	    OUT_W=1920
	    OUT_H=1080
	    ;;
	*)
	    OUT_W=640
	    OUT_H=360
	    #echo "Not a recognized output size setting -o $1." >&2
	    #echo "$USAGE" 
	    #exit 1
	    ;;
    esac
}

set_scale ()
{
    NEW_H=$1
    OLD_W=$2
    OLD_H=$3
    if [ ${NEW_H} -gt ${OLD_H} ] ; then
	echo "Scaled height (${NEW_H}) must not be larger then "
	echo "the original (${OLD_H})" >&2
	exit 1
    fi
    NEW_W=$(echo ${OLD_W}*${NEW_H} / ${OLD_H} | bc)
}

while getopts ":hb:c:f:g:i:o:r:s:tv:x:y:" opt; do
    case $opt in
	h)
	    echo "$USAGE" 
	    echo "Current list of configured stream names:"
	    for stream in ${STREAM_TYPES}; do 
		echo "  * $stream ${STREAM_DESCS[$stream]}"
	    done
	    echo "Example use: ${0} -o 360p youtube"
	    echo
	    exit 0
	    ;;
	b)
	    AB=$OPTARG
	    ;;
	c)
	    AC=$OPTARG
	    ;;
	f)
	    OUTFILE=$OPTARG
	    echo "Recording to file $OUTFILE" 
	    ;;
	g)
	    GRABSIZE=$OPTARG
	    set_this_wh $OPTARG
	    GRAB_W=$THIS_W
	    GRAB_H=$THIS_H
	    ;;
	i)
	    INSIZE=$OPTARG
	    set_this_wh $OPTARG
	    CAM_W=$THIS_W
	    CAM_H=$THIS_H
	    ;;
	o)
	    OUTSIZE=$OPTARG
	    ;;
	r)
	    FRATE=$OPTARG
	    ;;
	s)
	    SCALETO=$OPTARG
	    if [ "$OUTSIZE" ] ; then
		echo "ignoring -s $OPTARG, -o $OUTSIZE is already set." >&2
	    elif [ "$GRAB_H" ] ; then
		set_scale ${OPTARG} ${GRAB_W} ${GRAB_H}
	    else
		set_scale ${OPTARG} ${CAM_W} ${CAM_H}
	    fi
	    WIDTH=$NEW_W
	    HEIGHT=$NEW_H
	    #scale=$SCALETO:force_original_aspect_ratio=decrease
	    ;;
	t)
	    TEST=True
	    echo "Running in test mode"
	    ;;
	v)
	    WEBCAM=$OPTARG
	    ;;
	x)
	    GRAB_X=$OPTARG
	    ;;
	y)
	    GRAB_Y=$OPTARG
	    ;;
	\?)
	    echo "Invalid option: -$OPTARG"  >&2
	    exit 1
	    ;;
	:)
	    echo "Option -$OPTARG requires a argument."  >&2
	    echo $USAGE 
	    exit 1
	    ;;
    esac
done
shift $((OPTIND-1))

get_windowinfo ()
{
    THIS_W=$1
    THIS_H=$2
    THIS_X=$3
    THIS_Y=$4
    echo "Got window info ${THIS_W}x${THIS_H} : ${X},${Y}"
}

# get the size of the root window
ROOTSCRN=$(xwininfo -root | awk '/-geo/{print $2}' | sed 's|\([0-9]*\)x\([0-9]*\).*|\1 \2|')
get_windowinfo ${ROOTSCRN}
ROOTX=$THIS_W
ROOTY=$THIS_H

check_size () 
{
    let XTOT=${1}+CAP_XSIZE
    if [ $ROOTX -lt $XTOT ] ; then
	echo "XTOT to big: ${XTOT}"
	exit 1
    else
	echo "X is good to go at ${XTOT}"
    fi
    let YTOT=${2}+CAP_YSIZE
    if [ $ROOTY -lt $YTOT ] ; then
	echo "YTOT to big: ${YTOT}"
	exit 1
    else
	echo "Y is good to go at ${YTOT}"
    fi
}

do_camcap ()
{
    NAME="camcap"
    OUTFILE="${NAME}_${DATE}.mkv"
    echo "  Using stream setup ${NAME}."
    echo 
    echo "  Settings: "
    echo "        Cam: ${CAM_W}x${CAM_H} webcam "
    echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "      Audio: ${AC} channel(s) at ${AB}kbps"
    echo "       File: ${OUTFILE}"
    echo 
    read -p "Hit any key to continue."
    echo " -- Type q to quit.-- "
    MIC="-f alsa -ar 44100 -ac ${AC} -i pulse"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -framerate ${VRATE} -i ${WEBCAM}"
    ACODEC="-c:a libfdk_aac -ac ${AC} -ab ${AB}k "
    VCODEC="-c:v libx264 -preset ultrafast -qp 0"
    OUTPUT="${SAVEDIR}/${OUTFILE}"
    $FFMPEG ${MIC} ${CAM} \
	${ACODEC} ${VCODEC} \
	"${OUTPUT}" 2>${SAVEDIR}/${NAME}.log
}

do_youtube () 
{
    NAME="youtube"
    FILE="${NAME}_${DATE}.mkv"
    echo "  Using stream setup ${NAME}."
    echo 
    echo "  Settings: "
    echo "        Cam: ${CAM_W}x${CAM_H} webcam"
    echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "      Audio: ${AC} channel(s) at ${AB}kbps"
    echo "      Sream: to YouTube.com."
    echo "       File: ${FILE}"
    echo 
    read -p "Hit any key to continue."
    echo " -- Type q to quit.-- "
    if [ "${CAM_W}x${CAM_H}" == "${OUT_W}x${OUT_H}" ] ; then
	VOPTS="-preset veryfast "
    else
	VOPTS="-s ${OUT_W}x${OUT_H} -preset veryfast "
    fi
    let GOP=(VRATE*2)-2
    MIC="-f alsa -ar 44100 -ac ${AC} -i pulse"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -framerate ${VRATE} -i ${WEBCAM}"
    ACODEC="-c:a libfdk_aac -ac ${AC} -ab ${AB}k -bsf:a aac_adtstoasc"
    VCODEC="-c:v libx264 ${VOPTS} -maxrate 560k -bufsize 2240k"
    OUTFMT="-f tee -map 0:a -map 1:v -flags +global_header"
    OUTFILE="${SAVEDIR}/${FILE}"
    if [ "$TEST" ] ; then 
	echo "Saving to test stream file: "
	echo "    ${SAVEDIR}/test_${NAME}.f4v"
	OUTPUT="${OUTFILE}|[f=flv]${SAVEDIR}/test_${NAME}.f4v"
    else 
	OUTPUT="${OUTFILE}|[f=flv]rtmp://a.rtmp.youtube.com/live2/${KEY}"
    fi
    $FFMPEG ${MIC} ${CAM} \
	${ACODEC} ${VCODEC} -pix_fmt yuv420p -g ${GOP} \
	${OUTFMT} "${OUTPUT}" 2>${SAVEDIR}/${NAME}.log
}

do_screencap ()
{
    NAME="screencap"
    GRABAREA="${GRAB_W}x${GRAB_H}"
    GRABXY="${GRAB_X},${GRAB_Y}"
    OUTFILE="${NAME}_${DATE}.mkv"
    echo "  Using stream setup ${NAME}."
    echo 
    echo "  Settings: "
    echo "      Screen: ${GRABAREA} at ${GRABXY} "
    echo "       Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "       Audio: ${AC} channel(s) at ${AB}kbps"
    echo "        File: ${OUTFILE}"
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    MIC="-f alsa -ar 44100 -ac ${AC} -i pulse"
    SCREEN="-video_size ${GRABAREA} -framerate ${VRATE} -i :0.0+${GRABXY}"
    ACODEC="-c:a libfdk_aac -ab ${AB}k -ar 44100 -ac ${AC}" 
    VCODEC="-c:v libx264 -preset fast -maxrate 1000k -bufsize 1000k"
    FILTER="scale=w=${OUT_W}:h=${OUT_H}"
    OUTPUT="${SAVEDIR}/${OUTFILE}"
    $FFMPEG ${MIC} -f x11grab ${SCREEN} \
	-filter:v "${FILTER}" \
	${ACODEC} ${VCODEC} \
	"${OUTPUT}" 2>${SAVEDIR}/${NAME}.log
} 

do_twitch ()
{
    NAME="twitch"
    GRABAREA="${GRAB_W}x${GRAB_H}"
    GRABXY="${GRAB_X},${GRAB_Y}"
    echo "  Using stream setup ${NAME}."
    echo 
    echo "  Settings: "
    echo "      Screen: ${GRABAREA} at ${GRABXY} "
    echo "       Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "       Audio: ${AC} channel(s) at ${AB}kbps"
    echo "      Stream: to Twitch.tv"
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    let GOP=VRATE*2-2
    MIC="-f alsa -ar 44100 -ac ${AC} -i pulse"
    SCREEN="-video_size ${GRABAREA} -framerate ${VRATE} -i :0.0+${GRABXY}"
    ACODEC="-c:a libfdk_aac -ab ${AB}k -ar 44100 -ac ${AC}" 
    VCODEC="-c:v libx264 -preset fast -maxrate 540k -bufsize 1080k"
    KFRAMES="expr:if(isnan(prev_forced_t),gte(t,2),gte(t,prev_forced_t+2))"
    FILTER="scale=w=${OUT_W}:h=${OUT_H}"
    OUTFMT="-f flv" 
    if [ "$TEST" ] ; then 
	echo "Saving to test stream file: ${SAVEDIR}/test_${NAME}.f4v"
	OUTPUT="${SAVEDIR}/test_${NAME}.f4v"
    else 
	OUTPUT="rtmp://live.twitch.tv/app/live_${TWITCHKEY}"
    fi
    $FFMPEG ${MIC} -f x11grab ${SCREEN} \
	-filter:v "${FILTER}" \
	${ACODEC} ${VCODEC} \
	-force_key_frames "${KFRAMES}" -pix_fmt yuv420p -g $GOP \
	${OUTFMT} "${OUTPUT}" 2>${SAVEDIR}/${NAME}.log
} 

do_twitchcam ()
{
    NAME="twitchcam"
    GRABAREA="${GRAB_W}x${GRAB_H}"
    GRABXY="${GRAB_X},${GRAB_Y}"
    echo "  Using stream setup ${NAME}."
    echo 
    echo "  Settings: "
    echo "      Screen: ${GRABAREA} at ${GRABXY} "
    echo "      webcam: ${CAM_W}x${CAM_H} inset at lowerleft."
    echo "       Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "       Audio: ${AC} channel(s) at ${AB}kbps"
    echo "      Stream: to Twitch.tv"
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    let GOP=VRATE*2-2
    MIC="-f alsa -ar 44100 -ac ${AC} -i pulse"
    SCREEN="-video_size ${GRABAREA} -framerate ${VRATE} -i :0.0+${GRABXY}"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -framerate ${VRATE} -i ${WEBCAM}"
    ACODEC="-c:a libfdk_aac -ab ${AB}k -ar 44100 -ac ${AC}" 
    VCODEC="-c:v libx264 -preset fast -maxrate 540k -bufsize 1080k"
    KFRAMES="expr:if(isnan(prev_forced_t),gte(t,2),gte(t,prev_forced_t+2))"
    FILTER="[1:v]scale=${OUT_W}x${OUT_H},setpts=PTS-STARTPTS[bg]; [2:v]setpts=PTS-STARTPTS[fg]; [bg][fg]overlay=0:H-h-18,format=yuv420p[out]"
    OUTFMT="-f flv"
    if [ "$TEST" ] ; then 
	echo "Saving to test stream file: ${SAVEDIR}/test_${NAME}.f4v"
	OUTPUT="${SAVEDIR}/test_${NAME}.f4v"
    else 
	OUTPUT="rtmp://live.twitch.tv/app/live_${TWITCHKEY}"
    fi
    $FFMPEG ${MIC} -f x11grab ${SCREEN} ${CAM} \
	-filter_complex "${FILTER}" -map "[out]" -map 0:a \
	${ACODEC} ${VCODEC} \
	-force_key_frames "${KFRAMES}" -pix_fmt yuv420p -g $GOP \
	${OUTFMT} "${OUTPUT}" 2>${SAVEDIR}/${NAME}.log
} 

do_grab ()
{
    echo "Click the mouse on the window you wish to capture" 
    WINDOWINFO=$(echo $(xwininfo| awk '/Corners|-geo/{print $2 }') | sed 's|+\([0-9]*\)+\([0-9]*\) \([0-9]*\)x\([0-9]*\).*|\3 \4 \1 \2|')
    get_windowinfo $WINDOWINFO
    echo "Clicked window was ${THIS_W}x${THIS_H} "
    echo "topleft corner at ${THIS_X},${THIS_Y}"
    read -p "Enter new WIDTHxHEIGHT and/or hit enter to continue. " NEW_WH
    if [ "$NEW_WH" ] ; then
	set_this_wh $NEW_WH
    fi
    read -p "Enter new X offset and/or hit enter to continue." NEW_X
    if [ "$NEW_X" ] ; then
	echo "Got NEW X ${NEW_X}"
	THIS_X="$NEW_X"
    fi
    read -p "Enter new Y offset and/or hit enter to continue." NEW_Y
    if [ "$NEW_Y" ] ; then
	echo "Got NEW Y ${NEW_Y}"
	THIS_Y="$NEW_Y"
    fi
    check_size $THIS_X $THIS_Y
}

case $1 in
# camcap youtube screencap twitch twitchcam 
    camcap)
	set_this 2 $AC
	AC=${THIS}
	let B=AC*64
	set_this $B $AB
	AB=${THIS}
	if [ ! "$OUTSIZE" ] ; then
	    $OUTSIZE=360p
	fi
	set_outsize $OUTSIZE
	if [ !$CAM_W ] ; then
	    CAM_W=$OUT_W
	    CAM_H=$OUT_H
	fi
	if [ $CAM_H -eq 480 ] ; then
	    set_this 24 $FRATE
	elif [ $CAM_H -eq 600 ] ; then
	    set_this 24 $FRATE
	elif [ $CAM_H -lt 480 ] ; then
	    set_this 30 $FRATE
	elif [ $CAM_H -lt 720 ] ; then
	    set_this 15 $FRATE
	elif [ $CAM_H -gt 720 ] ; then
	    set_this 5 $FRATE
	else 
	    set_this 10 $FRATE
	fi
	VRATE=${THIS}
	do_camcap
	;;
    youtube)
	set_this 2 $AC
	AC=${THIS}
	let B=AC*64
	set_this $B $AB
	AB=${THIS}
	if [ ! "$OUTSIZE" ] ; then
	    $OUTSIZE=360p
	fi
	if [ ! "$KEY" ] ; then
	    KEY=YOUTUBEKEY[$OUTSIZE]
	fi
	if [ ! "$KEY" ] ; then
	    echo "You Tube Key not found for -o $OUTSIZE"
	    # let them input key a key here?
	    exit 1
	fi
	set_outsize $OUTSIZE
	if [ ! "$CAM_W" ] ; then
	    CAM_W=$OUT_W
	    CAM_H=$OUT_H
	fi
	if [ $CAM_H -eq 480 ] ; then
	    set_this 24 $FRATE
	elif [ $CAM_H -lt 480 ] ; then
	    set_this 30 $FRATE
	elif [ $CAM_H -lt 720 ] ; then
	    set_this 15 $FRATE
	else 
	    set_this 10 $FRATE
	fi
	VRATE=${THIS}
	do_youtube
	;;
    screencap)
	set_this 1 $AC
	AC=${THIS}
	let B=AC*64
	set_this $B $AB
	AB=${THIS}
	if [ !$OUTSIZE ] ; then
	    OUTSIZE=720p
	fi
	set_outsize $OUTSIZE
	if [ ! "$GRAB_W" ] ; then
	    do_grab
	    GRAB_W=${THIS_W}
	    GRAB_H=${THIS_H}
	fi
	if [ ! "$GRAB_X" ] ; then
	    do_grab
	    GRAB_X=${THIS_X}
	    GRAB_Y=${THIS_Y}
	fi
	set_this 15 $FRATE
	VRATE=${THIS}
	do_screencap
	;;
    twitch*)
	KEY=${TWITCHKEY}
	set_this 1 $AC
	AC=${THIS}
	let B=AC*48
	set_this $B $AB
	AB=${THIS}
	if [ !$OUTSIZE ] ; then
	    OUTSIZE=504
	fi
	set_outsize $OUTSIZE
	if [ ! "$GRAB_W" ] ; then
	    do_grab
	    GRAB_W=${THIS_W}
	    GRAB_H=${THIS_H}
	    GRAB_X=${THIS_X}
	    GRAB_Y=${THIS_Y}
	fi
	if [ ! "$GRAB_X" ] ; then
	    do_grab
	    GRAB_X=${THIS_X}
	    GRAB_Y=${THIS_Y}
	fi
	set_this 10 $FRATE
	VRATE=${THIS}
	;;&
    twitch)
	do_twitch
	;;
    twitchcam)
	if [ ! "$CAM_W" ] ; then
	    CAM_W=176
	    CAM_H=144
	fi
	do_twitchcam
	;;
    *)
	echo "No configured stream setup name given"  >&2
	exit 1
	;;
esac

#    Stream #0:0: Video: rawvideo (YUY2 / 0x32595559), yuyv422, 640x360, q=2-31, 200 kb/s, 30 fps, 30 tbn, 30 tbc

# Some of my webcam's native resolutions
# see: ffmpeg -f v4l2 -list_formats all -i /dev/video0
# also see: v4l2-ctl --list-formats-ext

## 17x9 (1.888)
#  176x144 30
#  544x288 30

## 1.818:
#  320x176 30

## 1.80769230769
# 752x416 30

## 1.80487804878
# 1184x656 15

## 1.80: 9x5 18x10
#  432x240 30
#  864x480 24.000

## 1.78571428571
# 800x448 30 

## 1.7778: 16x9
#  640x360 30
#  1024x576 15 
#  1280x720 10
#  1792x1008 5
#  1920x1080 5

## 1.76470588235
# 960x544 20

## 1.333: 4x3 12x9 ‘vga’
#  160x120 ‘qqvga’ 30
#  320x240 qvga’ 30
#  640x480 ‘vga’ 30
#  800x600 ‘svga’ 24
#  960x720  'DVCpro HD' 15
#  1280x960  7.5

## 1.222: 11x9 ‘cif’
#  176x144 ‘qcif’
#  352x288 ‘cif’

# ‘qqvga’ 160x120 
# ‘qvga’ 320x240
# ‘vga’ 640x480
# ‘svga’ 800x600

# ‘xga’ 1024x768

# ‘wvga’ 852x480

# ‘cga’ 320x200
# ‘ega’ 640x350

# ‘hd480’ 852x480 # ‘wvga’
# ‘hd720’ 1280x720
# ‘hd1080’ 1920x1080

#ffmpeg -f alsa -ar 44100 -ac 2 -i pulse -f v4l2 -video_size 640x360 -i /dev/video0 -c:v libx264 -preset ultrafast -qp 0 output.mkv
# -set-fmt-video=width=<w>,height=<h>,pixelformat=<f>

# v4l2-ctl --get-parm