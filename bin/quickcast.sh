#!/bin/bash

PROGNAME="quickcast.sh"
VERSION="0.3.1-alpha.1"

CONFIGFILE="${HOME}/.quickcast"
# if a special ffmpeg is needed and other variables
#FFMPEG="ffmpeg -loglevel warning"
FFMPEG="ffmpeg -y -loglevel info"
DATE=`date +%Y-%m-%d_%H%M%S`

source "${CONFIGFILE}"

USAGE="
USAGE: ${PROGNAME} [options] <stream_type>
  Options:
      -h
          Output this help
      -b <Audio bitrate>
          The bitrate for the aac audio codec in kbps. 
          The default is 48*<number of channels> for Twitch streams 
          and 64*<number of channels> for everything else. 
      -c <Audio_channels>
          The number of audio channels 1 (mono) or 2 (stereo.)
           The default is 1 for Twitch streams and 2 for everthing else.
      -C <CBR>
          The 'constant bit rate' setting for the video in kbps. Note that 
          this is not true CBR, the encoder will attempt to gravitate toward 
          this setting though. This only makes sense for Twitch.tv streams
          since they seem to insist on this non-sense. If omitted then mode
          is not used, just the maxrate setting, (See -M) which is what they 
          really want I think, even if they don't want to admit it). 
          This overides the -M setting.
      -g <size>
          Sets the screen grab capture dimensions of the form WIDTHxHEIGHT
          If omitted it is selected interactively via clicking on the 
          desired window for Twitch streams or for Screen captures, and 
          no screen is grabbed for everythihg else. 
      -i <size>
          Size of the input video from the webcam, one of:
            160x120 176x144 352x288 432x240 640x360 864x480 1280x720
          The first 3 are more square-ish (qqvga, qcif cif), good for insets.
          The others are 16x9 (or almost).  If omitted the webcam is not 
          used for Twitch streams or Screen captures and the output size 
          is used for everthing else.
      -K <streaming-key>
          The streaming key to use for the YouTube or Twitch stream 
          (the option is ignored otherwise.) By default the proper key 
          is selected from ${CONFIGFILE}
      -M <max-bitrate>
          The max bitrate of the video encoder in kbps, the default depends 
          on the stream type. (around 600 for YouTube and Twitch streams)
          Remember to add the audio bitrate to this if you want to determine 
          what the final bitrate will be. Overridden by the -C setting
      -o <output_height> 
          Sets the output height, where <output_height> is one of:
             240p 360p 450 480p 504 540 576 720p 900 1008 and 1080p
          The width will then be set to a hardcoded (~16x9) dimension 
          unless the -s option is used (See below).
          240p, 360p 480p and 720p could be used to live stream to YouTube.
          The defaults are:
          720p for 'camcap', 360p for 'youtube', 504 for the 'twitch' 
          and 'twitchcam' streams. For 'screencap' in input sized is used.
      -Q <quality-preset>
          One of ultrafast, superfast, veryfast, faster, fast, medium, 
          slow, slower, veryslow. The default epends on the stream type.
          faster is easier on the CPU for a given bitrate although the 
          result will be lower quality. If the fps isn't keeping up with
          the desired number either increase the preset speed or lower 
          the video size.
      -r <vrate>
          The video frame rate. If omitted defaults depends on the output
          video size configuration.
      -s 
          Scales the screen grab (or webcam) width to the output height (-o)
          maintaining the same ration as the input. Without this option a 
          standard (~16x9-ish) width will be used, potentially stretching 
          or shrinking the width dimension if the original (cam or grab area) 
          was not also in 16x9.
      -t
          Test run, does not stream, instead saves what would have been 
          streamed to:  test_<stream_name>.f4v
      -T <tune-settings> NOT IMPLEMENTED
          x264 'tune' setting to use. Default depends on the stream type.
          film, animation or zerolatency are the obvious choices, 
          however best to omit unless you are sure.
      -U <rtmp://example.com/path>
          Overrides the URL for streaming to YouTube or Twitch, otherwise 
          the applicable one found in ${CONFIGFILE} is used.
          eg: -U rtmp://a.rtmp.youtube.com/live2
      -v <v4l2_capture_device>
          If omitted ${WEBCAM} is used.
      -V 
          Print the program's version number and exit.
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
# not currently being used
{
    set_this_wh $1
    v4l2-ctl --set-fmt-video=width=${THIS_W},height=${THIS_H},pixelformat=YUYV
}


set_this ()
# sets THIS to the REQUESTED value or the DEFAULT
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
# sets the the output dimensions from the height moniker
{
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
	    # Using the 864x480 my logitech cam does. 
	    # Maybe should use 'hd480' (852x480) though?
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
	    # Another 16x9 logitech cam size
	    # Given my current set up this is probably the largest I should 
	    # even think about streaming to twitch
	    OUT_W=1024
	    OUT_H=576
	    ;; 
	720p) 
	    # aka hd720. My logitech cam can only do 10fps at this size
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
    if [ "${NEW_H}" -gt "${OLD_H}" ] ; then
	echo "Scaled height (${NEW_H}) must not be larger then "
	echo "the original (${OLD_H})" >&2
	exit 1
    fi
    NEW_W=$(echo ${OLD_W}*${NEW_H} / ${OLD_H} | bc)
}

while getopts ":Vhb:c:C:f:g:i:K:M:o:r:stU:v:x:y:" opt; do
    case $opt in
	V)
	    echo "${PROGNAME} ${VERSION}"
	    exit 0
	    ;;
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
	C)
	    CBR=$OPTARG
	    ;;
	g)
	    GRABSIZE=$OPTARG
	    set_this_wh $OPTARG
	    GRAB_W=$THIS_W
	    GRAB_H=$THIS_H
	    ;;
        K)
	    KEY=$OPTARG
	    ;;
	i)
	    INSIZE=$OPTARG
	    set_this_wh $OPTARG
	    CAM_W=$THIS_W
	    CAM_H=$THIS_H
	    ;;
	M)
	    MAXRATE=$OPTARG
	    ;;
	o)
	    OUTSIZE=$OPTARG
	    ;;
        Q)
	    QUALITY=$OPTARG
	    ;;
	r)
	    FRATE=$OPTARG
	    ;;
	s)
	    SCALE=True
	    ;;
	t)
	    TEST=True
	    echo "Running in test mode"
	    ;;
	T)
	    # not in use
	    TUNE=$OPTARG
	    ;;
	U)
	    URL=$OPTARG
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
	    echo "$USAGE" 
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
    #echo "Got window info ${THIS_W}x${THIS_H} : ${X},${Y}"
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
	let THIS_X=ROOTX-CAP_XSIZE
	echo "XTOT to big at ${XTOT} adjusting X offest to ${THIS_X}"
    else
	echo "XTOT is good to go at ${XTOT}"
    fi
    let YTOT=${2}+CAP_YSIZE
    if [ $ROOTY -lt $YTOT ] ; then
	let THIS_Y=ROOTY-CAP_YSIZE
	echo "YTOT to big at ${YTOT} adjusting Y offest to ${THIS_Y}"
    else
	echo "YTOT is good to go at ${YTOT}"
    fi
}

do_camcap ()
{
    NAME="camcap"
    OUTFILE="${NAME}_${DATE}.mkv"
    echo "  Using stream setup ${NAME}."
    echo 
    echo " --- Settings -------- "
    echo "        Cam: ${CAM_W}x${CAM_H} webcam "
    echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "      Audio: ${AC} channel(s) at ${AB}kbps"
    echo "       File: ${OUTFILE}"
    echo " --------------------- "
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
    echo " --- Settings -------- "
    echo "        Cam: ${CAM_W}x${CAM_H} webcam"
    echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "      Audio: ${AC} channel(s) at ${AB}kbps"
    if [ "$TEST" ] ; then 
	echo "Saving to test stream file: "
	echo "     ${SAVEDIR}/test_${NAME}.f4v"
    else
	echo "      Stream: ${URL}/${KEY}"
    fi
    echo " Local File: ${FILE}"
    echo " --------------------- "
    echo
    read -p "Hit any key to continue."
    echo " -- Type q to quit.-- "
    if [ "${CAM_W}x${CAM_H}" == "${OUT_W}x${OUT_H}" ] ; then
	VSIZE=""
    else
	VSIZE="-s ${OUT_W}x${OUT_H}"
    fi
    let GOP=(VRATE*2)
    MIC="-f alsa -ar 44100 -ac ${AC} -i pulse"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -framerate ${VRATE} -i ${WEBCAM}"
    ACODEC="-c:a libfdk_aac -ac ${AC} -ab ${AB}k -bsf:a aac_adtstoasc"
    VCODEC="-c:v libx264 ${VSIZE} ${QUALITY} ${BRATE}"
    OUTFMT="-f tee -map 0:a -map 1:v -flags +global_header"
    OUTFILE="${SAVEDIR}/${FILE}"
    if [ "$TEST" ] ; then 
	OUTPUT="${OUTFILE}|[f=flv]${SAVEDIR}/test_${NAME}.f4v"
    else 
	OUTPUT="${OUTFILE}|[f=flv]${URL}/${KEY}"
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
    echo " --- Settings -------- "
    echo "      Screen: ${GRABAREA} at ${GRABXY} "
    echo "       Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "       Audio: ${AC} channel(s) at ${AB}kbps"
    echo "        File: ${OUTFILE}"
    echo " --------------------- "
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    MIC="-f alsa -ar 44100 -ac ${AC} -i pulse"
    #SOUND="-f alsa -ar 44100 -ac ${AC} -i pulse"
    #MONITOR="-f alsa -ar 44100 -ac ${AC} -i pulse"
    SCREEN="-video_size ${GRABAREA} -framerate ${VRATE} -i :0.0+${GRABXY}"
    ACODEC="-c:a libfdk_aac -ab ${AB}k -ar 44100 -ac ${AC}" 
    VCODEC="-c:v libx264 -preset ultrafast -qp 0"
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
    echo " --- Settings -------- "
    echo "      Screen: ${GRABAREA} at ${GRABXY} "
    echo "       Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "       Audio: ${AC} channel(s) at ${AB}kbps" 
    if [ "$TEST" ] ; then 
	echo "Saving to test stream file: "
	echo "     ${SAVEDIR}/test_${NAME}.f4v"
    else
	echo "      Stream: ${URL}/${KEY}"
    fi
    echo " --------------------- "
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    # An effort to no go over 2 sec keyframes that Twitch complains about
    # divide by 1 to make it an integer, setting GOP to VRATE*2 still
    # resulted in twitch complaining about max key intervals  being 
    # 3 seconds or more!
    GOP=$(echo "(${VRATE}*1.33)/1" | bc)
    MIC="-f alsa -ar 44100 -ac ${AC} -i pulse"
    SCREEN="-video_size ${GRABAREA} -framerate ${VRATE} -i :0.0+${GRABXY}"
    ACODEC="-c:a libfdk_aac -ab ${AB}k -ar 44100 -ac ${AC}" 
    VCODEC="-c:v libx264 ${QUALITY} ${BRATE}"
    # KFRAMES is another attempt to keep key intervals at 2 seconds
    KFRAMES="expr:if(isnan(prev_forced_t),gte(t,2),gte(t,prev_forced_t+2))"
    FILTER="scale=w=${OUT_W}:h=${OUT_H}"
    OUTFMT="-f flv" 
    if [ "$TEST" ] ; then 
	OUTPUT="${SAVEDIR}/test_${NAME}.f4v"
    else 
	OUTPUT="${URL}/${KEY}"
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
    echo " --- Settings -------- "
    echo "      Screen: ${GRABAREA} at ${GRABXY} "
    echo "      webcam: ${CAM_W}x${CAM_H} inset at lowerleft."
    echo "       Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    echo "       Audio: ${AC} channel(s) at ${AB}kbps"
    if [ "$TEST" ] ; then 
	echo "Saving to test stream file: "
	echo "     ${SAVEDIR}/test_${NAME}.f4v"
    else
	echo "      Stream: ${URL}/${KEY}"
    fi
    echo " --------------------- "
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    let GOP=VRATE*2-2
    MIC="-f alsa -ar 44100 -ac ${AC} -i pulse"
    SCREEN="-video_size ${GRABAREA} -framerate ${VRATE} -i :0.0+${GRABXY}"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -framerate ${VRATE} -i ${WEBCAM}"
    ACODEC="-c:a libfdk_aac -ab ${AB}k -ar 44100 -ac ${AC}" 
    VCODEC="-c:v libx264 ${QUALITY} ${BRATE}"
    KFRAMES="expr:if(isnan(prev_forced_t),gte(t,2),gte(t,prev_forced_t+2))"
    FILTER="[1:v]scale=${OUT_W}x${OUT_H},setpts=PTS-STARTPTS[bg]; [2:v]setpts=PTS-STARTPTS[fg]; [bg][fg]overlay=0:H-h-18,format=yuv420p[out]"
    OUTFMT="-f flv"
    if [ "$TEST" ] ; then 
	echo "Saving to test stream file: ${SAVEDIR}/test_${NAME}.f4v"
	OUTPUT="${SAVEDIR}/test_${NAME}.f4v"
    else 
	OUTPUT="${URL}/${KEY}"
    fi
    $FFMPEG ${MIC} -f x11grab ${SCREEN} ${CAM} \
	-filter_complex "${FILTER}" -map "[out]" -map 0:a \
	${ACODEC} ${VCODEC} \
	-force_key_frames "${KFRAMES}" -pix_fmt yuv420p -g $GOP \
	${OUTFMT} "${OUTPUT}" 2>${SAVEDIR}/${NAME}.log
} 

do_grabarea ()
{
    echo "Click the mouse on the window you wish to capture" 
    WINDOWINFO=$(echo $(xwininfo| awk '/Corners|-geo/{print $2 }') | sed 's|+\([0-9]*\)+\([0-9]*\) \([0-9]*\)x\([0-9]*\).*|\3 \4 \1 \2|')
    get_windowinfo $WINDOWINFO
    echo "Clicked window was ${THIS_W}x${THIS_H} "
    read -p "Enter new WIDTHxHEIGHT and/or hit enter to continue. " NEW_WH
    if [ "$NEW_WH" ] ; then
	set_this_wh $NEW_WH
    fi
}

do_grabxy ()
{
    echo "Top-left corner at ${THIS_X},${THIS_Y}"
    read -p "Enter new X,Y offset and/or hit enter to continue." NEW_X NEW_Y
    if [ "$NEW_X" ] ; then
	echo "Got NEW X,Y ${NEW_X},${NEW_Y}"
	THIS_X="$NEW_X"
	THIS_Y="$NEW_Y"
    fi
    check_size $THIS_X $THIS_Y
}

do_coordinates ()
{
    if [ ! "$GRAB_W" ] ; then
	do_grabarea
	GRAB_W=${THIS_W}
	GRAB_H=${THIS_H}
    fi
    if [ ! "$GRAB_X" ] ; then
	do_grabxy
	GRAB_X=${THIS_X}
	GRAB_Y=${THIS_Y}
    fi
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
	elif [ "$SCALE" ] ; then
	    set_scale $OUT_H $CAM_W $CAM_H
	    OUT_W=$NEW_W
	fi
	if [ "$CAM_H" -eq 480 ] ; then
	    set_this 24 $FRATE
	elif [ "$CAM_H" -eq 600 ] ; then
	    set_this 24 $FRATE
	elif [ "$CAM_H" -lt 480 ] ; then
	    set_this 30 $FRATE
	elif [ "$CAM_H" -lt 720 ] ; then
	    set_this 15 $FRATE
	elif [ "$CAM_H" -gt 720 ] ; then
	    set_this 5 $FRATE
	else 
	    set_this 10 $FRATE
	fi
	VRATE=${THIS}
	do_camcap
	;;
    screencap)
	set_this 1 $AC
	AC=${THIS}
	let B=AC*64
	set_this $B $AB
	AB=${THIS}
	do_coordinates
	if [ ! "$OUTSIZE" ] ; then
	    OUT_W=${GRAB_W}
	    OUT_H=${GRAB_H}
	else
	    set_outsize $OUTSIZE
	fi
	if [ "$SCALE" ] ; then
	    set_scale $OUT_H $GRAB_W $GRAB_H
	    OUT_W=$NEW_W
	fi
	set_this 15 $FRATE
	VRATE=${THIS}
	do_screencap
	;;
    twitch*|youtube)
	if [ ! "${QUALITY}" ] ; then
	    QUALITY="-preset veryfast"
	fi
	if [ "${CBR}" ] ; then
	    BRATE="-b:v ${CBR}k -minrate ${CBR}k -maxrate ${CBR}k -bufsize ${CBR}k" 
	elif [ "${MAXRATE}" ] ; then
	    BRATE="-maxrate ${MAXRATE}k -bufsize ${MAXRATE}k"
	else
	    BRATE="-maxrate ${BANDWIDTH}k -bufsize ${BANDWIDTH}k"
	fi
	;;&
    youtube)
	set_this 2 $AC
	AC=${THIS}
	let B=AC*64
	set_this $B $AB
	AB=${THIS}
	if [ ! "$OUTSIZE" ] ; then
	    OUTSIZE=360p
	fi
	if [ ! "${URL}" ] ; then
	    URL="${YOUTUBE_URL}"
	fi
	if [ ! "$KEY" ] ; then
	    KEY=${YOUTUBEKEYS[$OUTSIZE]}
	fi
	if [ ! "$KEY" ] ; then
	    echo "YouTube Key not found for -o $OUTSIZE"
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
    twitch*)
	if [ ! "${URL}" ] ; then
	    URL="${TWITCH_URL}"
	fi
	if [ ! "$KEY" ] ; then
	    KEY="${TWITCHKEY}"
	fi
	if [ ! "$KEY" ] ; then
	    echo "Key not found for twitch"
	    exit 1
	fi
	set_this 1 $AC
	AC=${THIS}
	let B=AC*48
	set_this $B $AB
	AB=${THIS}
	if [ ! "$OUTSIZE" ] ; then
	    OUTSIZE=504
	fi
	set_outsize $OUTSIZE
	do_coordinates
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
	echo "No configured stream setup name given!"  >&2
	echo "Available configurations are:" >&2
	echo "  ${STREAM_TYPES}" >&2
	echo "Example: ${PROGNAME} $(echo ${STREAM_TYPES} | awk '{print $1}')"
	exit 1
	;;
esac

