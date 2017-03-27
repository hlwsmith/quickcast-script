#!/bin/bash

PROGNAME="quickcast.sh"
VERSION="0.4.2b1"

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
          really want I think, even if they don't want to admit it. ;-) 
          This overides the -M setting.
      -g <size>
          Sets the screen grab capture dimensions of the form WIDTHxHEIGHT
          If omitted it is selected interactively via clicking on the 
          desired window for Twitch streams or for Screen captures, and 
          no screen is grabbed for everythihg else. 
      -i <size>
          Size of the input video from the webcam, one of:
            160x120 176x144 352x288 432x240 640x360 864x480 1024x576 1280x720
          The first 3 are more square-ish (qqvga, qcif cif), good for
          insets.  The others are 16x9 (or almost).  If omitted
          640x360 is used for camcap and screencap, 176x144 (qcif) is used
          for the twitchcam inset and the remaining modes will not use 
          the camera.
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
          360p for 'youtube', 504 for the 'twitch' and 'twitchcam'
          streams. For 'screencap' and 'camcap' the input sized is
          used.
      -Q <quality-preset>
          One of ultrafast, superfast, veryfast, faster, fast, medium,
          slow, slower, veryslow. The default depends on the stream
          type.  faster is easier on the CPU for a given bitrate
          although the result will be a bigger file (and more stream
          bandwidth). If the fps isn't keeping up with the desired
          number either increase this preset, or lower the video
          size.
      -r <vrate>
          The video frame rate. If omitted defaults depends on the output
          video size configuration and mode.
      -R <audio sample rate>
          in hz
      -s 
          Scales the screen grab (or webcam) width to the output height (-o)
          maintaining the same ration as the input. Without this option a 
          standard (~16x9-ish) width will be used, potentially stretching 
          or shrinking the width dimension if the original (cam or grab area) 
          was not also in 16x9.
      -S
          Skip the option dialogs, taking the defaults without querying 
          for conformation.
      -t
          Test run, does not stream, instead saves what would have
          been streamed to: test_<stream_name>.f4v. This only effects
          the modes that stream to the internet (twitch, twitchcam
          and youtube). This option is ignored for other stream types.
      -T <tune-setting> NOT IMPLEMENTED
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

while getopts ":Vhb:c:C:f:g:i:K:M:o:Q:r:R:sStU:v:x:y:" opt; do
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
	R)
	    SAMPLES=$OPTARG
	    ;;
	s)
	    SCALE=True
	    ;;
	S)
	    SKIP=True
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
    if [ $3 ]; then
	THIS_X=$3
    else
	THIS_X="0"
    fi
    if [ $4 ];then
	THIS_Y=$4
    else
	THIS_Y="0"
    fi
    #echo "Got window info ${THIS_W}x${THIS_H} : ${THIS_X},${THIS_Y}"
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
    echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps (${QUALITY})"
    echo "      Audio: ${AC} channel(s) at ${SAMPLES} to ${AB}kbps"
    echo "       File: ${OUTFILE}"
    echo " --------------------- "
    echo 
    read -p "Hit any key to continue."
    echo " -- Type q to quit.-- "
    MIC="-f alsa -ar ${SAMPLES} -ac ${AC} -i pulse"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -i ${WEBCAM}"
    ACODEC="-c:a libfdk_aac -ac ${AC} -ab ${AB}k "
    # just letting the underlying ffmpeg decide on the framerate here
    #VCODEC="-c:v libx264 -preset ${QUALITY} -qp 0 -r:v ${VRATE}"
    VCODEC="-c:v libx264 -preset ${QUALITY} -qp 0"
    OUTPUT="${SAVEDIR}/${OUTFILE}"
    $FFMPEG ${MIC} ${CAM} \
	${ACODEC} ${VCODEC} \
	"${OUTPUT}" 2>${SAVEDIR}/${NAME}.log
}

do_youtube () 
{
    NAME="youtube"
    OUTFILE="${NAME}_${DATE}.mkv"
    echo "  Using stream setup ${NAME}."
    echo 
    echo " --- Settings -------- "
    echo "        Cam: ${CAM_W}x${CAM_H} webcam"
    echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps (${QUALITY})"
    echo "      Audio: ${AC} channel(s) at ${SAMPLES} to ${AB}kbps"
    if [ "$TEST" ] ; then 
	echo "Saving to test stream file: "
	echo "     ${SAVEDIR}/test_${NAME}.f4v"
    else
	echo "      Stream: ${URL}/${KEY}"
    fi
    echo "       File: ${OUTFILE}"
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
    MIC="-f alsa -ar ${SAMPLES} -i pulse"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -i ${WEBCAM}"
    ACODEC="-c:a libfdk_aac -ac ${AC} -ab ${AB}k -bsf:a aac_adtstoasc"
    VCODEC="-c:v libx264 ${VSIZE} -r:v ${VRATE} -preset ${QUALITY} ${BRATE}"
    OUTFMT="-f tee -map 0:a -map 1:v -flags +global_header"
    OUTPUT="${SAVEDIR}/${OUTFILE}"
    if [ "$TEST" ] ; then 
	OUTPUT="${SAVEDIR}/${OUTFILE}|[f=flv]${SAVEDIR}/test_${NAME}.f4v"
    else 
	OUTOUT="${SAVEDIR}/${OUTFILE}|[f=flv]${URL}/${KEY}"
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
    OUTFILE="${NAME}_${DATE}.avi"
    echo "  Using stream setup ${NAME}."
    echo 
    echo " --- Settings -------- "
    echo "     Screen: ${GRABAREA} at ${GRABXY} "
    echo "      Video: ${OUT_W}x${OUT_H} (${QUALITY})"
    echo "      Audio: ${AC} channel(s) at ${SAMPLES} to ${AB}kbps"
    echo "       File: ${OUTFILE}"
    echo " --------------------- "
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    MIC="-f alsa -ar ${SAMPLES} -i pulse"
    SCREEN="-video_size ${GRABAREA} -framerate 30 -i :0.0+${GRABXY}"
    ACODEC="-c:a libfdk_aac -ac ${AC} -ab ${AB}k" 
    VCODEC="-c:v libx264 -preset ${QUALITY} -qp 0"
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
    echo "     Screen: ${GRABAREA} at ${GRABXY} "
    echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps (${QUALITY})"
    echo "      Audio: ${AC} channel(s) at ${SAMPLES} to ${AB}kbps"
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
    MIC="-f alsa -ar ${SAMPLES} -i pulse"
    SCREEN="-video_size ${GRABAREA} -i :0.0+${GRABXY}"
    ACODEC="-c:a libfdk_aac -ac ${AC} -ab ${AB}k" 
    VCODEC="-c:v libx264 -preset ${QUALITY} ${BRATE} -r:v ${VRATE}"
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
    echo "     Screen: ${GRABAREA} at ${GRABXY} "
    echo "     webcam: ${CAM_W}x${CAM_H} inset at lowerleft."
    echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps (${QUALITY})"
    echo "      Audio: ${AC} channel(s) at ${SAMPLES} to ${AB}kbps"
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
    MIC="-f alsa -ar ${SAMPLES} -i pulse"
    SCREEN="-video_size ${GRABAREA} -i :0.0+${GRABXY}"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -i ${WEBCAM}"
    ACODEC="-c:a libfdk_aac -ac ${AC} -ab ${AB}k" 
    VCODEC="-c:v libx264 -preset ${QUALITY} ${BRATE} -r:v ${VRATE}"
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
    OLD_IFS="$IFS"
    IFS="${IFS},x"
    read -p "Enter new X,Y offset and/or hit enter to continue." NEW_X NEW_Y
    if [ "$NEW_X" ] ; then
	echo "Got NEW X,Y ${NEW_X},${NEW_Y}"
	THIS_X="$NEW_X"
	THIS_Y="$NEW_Y"
    fi
    IFS=${OLD_IFS}
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


if [ ! $1 ]; then
    STREAM_TYPE=$(whiptail --title "Select a Stream Type" --menu \
	"Choose a Stream Type from the list:" 12 72 5 \
	"camcap" "Capture the webcam and save locally " \
	"youtube" "Like camcap also streaming to YouTube.com " \
	"screencap" "Screen grab and save locally " \
	"twitch" "Like screencap also streaming to Twitch.tv " \
	"twitchcam" "Like twitch with webcam inset at lower left " \
	3>&1 1>&2 2>&3)
else
    STREAM_TYPE=${1}
fi

function query_webcam ()
# 160x120 176x144 352x288 432x240 640x360 864x480 1280x720
{
    if INSIZE=$(whiptail --title "Input Video Dimensions" \
	--nocancel --radiolist \
	"Choose dimensions for the video camera:" 15 60 8 \
	"160x120" "160x120 qqvga -- max fps 30" OFF \
	"176x144" "176x144 qcif -- max fps 30" OFF \
	"352x288" "352x288 cif -- max fps 30" OFF \
	"432x240" "432x240 -- max fps 30" OFF \
	"640x360" "640x360 -- max fps 30" ON \
	"864x480" "864x480 -- max fps 24" OFF \
	"1024x576" "1024x576 -- max fps 15" OFF \
	"1280x720" "1280x720 -- max fps 10" OFF 3>&1 1>&2 2>&3); 
    then
	set_this_wh $INSIZE
	CAM_W=$THIS_W
	CAM_H=$THIS_H
    fi
}

function query_outsize() {
# For use with YouTube 240p 360p 480p 720p
    if OUTSIZE=$(whiptail --title "Output Video Dimensions" \
	--nocancel --radiolist \
	"Choose dimensions for the streaming video:" 12 60 4 \
	"240p" "432x240 -- fps 24" OFF \
	"360p" "640x360 -- fps 24" ON \
	"480p" "864x480 -- fps 24" OFF \
	"720p" "1280x720 -- fps 10" OFF 3>&1 1>&2 2>&3); 
    then
	set_outsize $OUTSIZE
    fi
}

function query_outsize_twitch() {
# For use with twitch.tv 
#   240p 360p 450 480p 504 540 576 720p 900 1008 and 1080p
    if OUTSIZE=$(whiptail --title "Video Encoder Settings" --radiolist \
	"Choose dimensions for the streaming video:" 20 60 8 \
	"240p" "432x240 -- fps 30" OFF \
	"360p" "640x360 -- fps 20" OFF \
	"450" "800x450 -- fps 15" ON \
	"480p" "864x480 -- fps 10" OFF \
	"504" "896x504 -- fps 10" OFF \
	"540" "960x540 -- fps 10" OFF \
	"576" "1024x576 -- fps 10" OFF \
	"720p" "1280x720 -- fps 10" OFF \
	3>&1 1>&2 2>&3); 
    then
	set_outsize $OUTSIZE
    fi
}

function query_outsize_screen() {
# For use with screen grabs
#   240p 360p 450 480p 504 540 576 720p 900 1008 and 1080p
    if OUTSIZE=$(whiptail --title "Video Encoder Settings" --radiolist \
	"Choose dimensions for the streaming video:" 18 60 11 \
	"240p" "432x240 -- fps 30" OFF \
	"360p" "640x360 -- fps 30" OFF \
	"450" "800x450 -- fps 24" ON \
	"480p" "864x480 -- fps 20" OFF \
	"504" "896x504 -- fps 20" OFF \
	"540" "960x540 -- fps 20" OFF \
	"576" "1024x576 -- fps 15" OFF \
	"720p" "1280x720 -- fps 15" OFF \
	"900" "1600x900 -- fps 10" OFF \
	"1008" "1792x1008 -- fps 10" OFF \
	"1080p" "1920x1080 -- fps 10" OFF \
	3>&1 1>&2 2>&3); 
    then
	set_outsize $OUTSIZE
    fi
}

function query_audio() {
    if [ "$AC" -eq 1 ] ; then
	STAT1=ON
	STAT2=OFF
    else
	STAT1=OFF
	STAT2=ON
    fi
    CHOICE=$(whiptail --title "Audio Options" --radiolist --nocancel \
	"Choose number of audio channels:" 10 60 2 \
	"1" "Mono " $STAT1 \
	"2" "Stereo " $STAT2 \
	3>&1 1>&2 2>&3)
    AC=$CHOICE
    STAT1=OFF
    STAT2=OFF
    STAT3=OFF
    STAT4=OFF
    #if [ ! "$AB" ]; then 
    case $AB in
	48)
	    STAT1=ON
	    ;;
	64)
	    STAT2=ON
	    ;;
	96)
	    STAT3=ON	    
	    ;;
	128)
	    STAT4=ON
	    ;;
    esac
    CHOICE=$(whiptail --title "Audio Options" --radiolist --nocancel \
	"Choose bitrate in kbps from list:" 10 60 4 \
	"48" "48 kbps " $STAT1 \
	"64" "64 kbps " $STAT2 \
	"96" "96 kbps " $STAT3 \
	"128" "128 kbps " $STAT4 \
	3>&1 1>&2 2>&3)
    AB=$CHOICE
}

function query_video() {
    #quality-preset #ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
    #vrate # 
    #tune-setting # film, animation or zerolatency
    #CBR # 'constant bit rate' setting for the video in kbps.
    #echo "VIDEO STUB"
    STAT1=OFF
    STAT2=OFF
    STAT3=OFF
    STAT4=OFF
    STAT5=OFF
    STAT6=OFF
    STAT7=OFF
    STAT8=OFF
    STAT9=OFF
    case ${QUALITY} in
	ultrafast)
	    STAT1=ON
	    ;;
	superfast)
	    STAT2=ON	    
	    ;;
	veryfast)
	    STAT3=ON
	    ;;
	faster)
	    STAT4=ON
	    ;;
	fast)
	    STAT5=ON
	    ;;
	medium)
	    STAT6=ON
	    ;;
	slow)
	    STAT7=ON
	    ;;
	slower)
	    STAT8=ON
	    ;;
	veryslow)
	    STAT9=ON
	    ;;
    esac
    CHOICE=$(whiptail --title "Video Encoder Options" --radiolist \
	"Choose a quality preset (faster is easier on the CPU):" 18 60 9 \
	"ultrafast" "ultrafast" $STAT1 \
	"superfast" "superfast" $STAT2 \
	"veryfast" "veryfast" $STAT3 \
	"faster" "faster" $STAT4 \
	"fast" "fast" $STAT5 \
	"medium" "medium" $STAT6 \
	"slow" "slow" $STAT7 \
	"slower" "slower" $STAT8 \
	"veryslow" "veryslow" $STAT9 \
	3>&1 1>&2 2>&3)
    QUALITY=$CHOICE
}

function query_stream() {
    #max-bitrate #  600 for YouTube and Twitch
    #streaming-key # 
    #stream_url # rtmp://example.com/path
    if CHOICE=$(whiptail --title "Stream Settings" --inputbox \
	"Url for the stream?" 10 60 ${URL} \
	3>&1 1>&2 2>&3); then
	URL="$CHOICE"
    else
	echo "Operation Canceled."
	exit
    fi
    if CHOICE=$(whiptail --title "Stream Settings" --inputbox \
	"The key for the stream?" 10 60 ${KEY} \
	3>&1 1>&2 2>&3); then
	KEY="$CHOICE"
    else
	echo "Operation Canceled."
	exit
    fi
    if CHOICE=$(whiptail --title "Stream Settings" --inputbox \
	"Uplink bandwidth in kbps?" 10 60 ${BANDWIDTH} \
	3>&1 1>&2 2>&3); then
	BANDWIDTH="$CHOICE"
    else
	echo "Operation Canceled."
	exit
    fi
    if whiptail --title "Stream Settings" --yesno --defaultno \
	"Is this a test run" 10 60; then
	TEST=True
    else
	TEST=
    fi
}

function query_options_local() {
    if OPTIONS=$(whiptail --title "Options" \
	--nocancel --checklist \
	"Choose Advanced Options to Configure:" 12 60 3 \
	"audio" "Audio Settings (${AC} channels at ${AB}kbps)" OFF \
	"video" "Video Encoder Settings" OFF \
	 3>&1 1>&2 2>&3);
    then
	for opt in $OPTIONS; do
	    query_$(echo ${opt}| sed 's|\"||g')
	done
    fi
}

function query_options_stream() {
    if OPTIONS=$(whiptail --title "Options" \
	--nocancel --checklist \
	"Choose Advanced Options to Configure:" 12 60 4 \
	"audio" "Audio Settings (${AC} channels at ${AB}kbps)" OFF \
	"video" "Video Encoder Settings" OFF \
	"stream" "Stream Settings" OFF \
	 3>&1 1>&2 2>&3);
    then
	for opt in $OPTIONS; do
	    query_$(echo ${opt}| sed 's|\"||g')
	done
    fi
}

case ${STREAM_TYPE} in
# camcap youtube screencap twitch twitchcam 
    camcap)
	if [ ! "${QUALITY}" ] ; then
	    QUALITY="faster"
	fi
	set_this 2 $AC
	AC=${THIS}
	let B=AC*64
	set_this $B $AB
	AB=${THIS}
	if [ ! "$CAM_W" ] ; then
	    query_webcam
	fi
	if [ "$OUTSIZE" ] ; then
	    set_outsize $OUTSIZE
	else
	    OUT_W=$CAM_W
	    OUT_H=$CAM_H
	fi
	if [ "$SCALE" ] ; then
	    set_scale $OUT_H $CAM_W $CAM_H
	    OUT_W=$NEW_W
	fi
	if [ "$CAM_H" -lt 600 ] ; then
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
	if [ ! "${SKIP}" ] ; then
	    query_options_local
	fi
	do_camcap
	;;
    screencap)
	if [ ! "${QUALITY}" ] ; then
	    QUALITY="faster"
	fi
	set_this 1 $AC
	AC=${THIS}
	let B=AC*64
	set_this $B $AB
	AB=${THIS}
	if [ "${OUTSIZE}" ] ; then
	    set_outsize $OUTSIZE
	else
	    query_outsize_screen
	fi
	do_coordinates
	if [ ! "$OUTSIZE" ] ; then
	    OUT_W=${GRAB_W}
	    OUT_H=${GRAB_H}
	fi
	if [ "$SCALE" ] ; then
	    set_scale $OUT_H $GRAB_W $GRAB_H
	    OUT_W=$NEW_W
	fi
	VRATE=30
	if [ ! "${SKIP}" ] ; then
	    query_options_local
	fi
	do_screencap
	;;
    twitch*|youtube)
	if [ ! "${QUALITY}" ] ; then
	    QUALITY="veryfast"
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
	if [ ! "$CAM_W" ] ; then
	    query_webcam
	fi
	if [ "$OUTSIZE" ] ; then
	    set_outsize $OUTSIZE
	else
	    query_outsize
	fi
	if [ ! "${URL}" ] ; then
	    URL="${YOUTUBE_URL}"
	fi
	if [ ! "$KEY" ] ; then
	    KEY=${YOUTUBEKEY}
	fi
	if [ ! "$KEY" ] ; then
	    echo "YouTube Key not found"
	    # TODO: let them input the key here?
	    exit 1
	fi
	if [ $CAM_H -eq 480 ] ; then
	    set_this 24 $FRATE
	elif [ $CAM_H -lt 480 ] ; then
	    set_this 24 $FRATE
	elif [ $CAM_H -lt 720 ] ; then
	    set_this 15 $FRATE
	else 
	    set_this 10 $FRATE
	fi
	VRATE=${THIS}
	if [ ! "${SKIP}" ] ; then
            query_options_stream
	fi
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
	if [ "${OUTSIZE}" ] ; then
	    set_outsize $OUTSIZE
	else
	    query_outsize_twitch
	fi
	if [ ! "$OUTSIZE" ] ; then
	    set_outsize 504
	fi
	do_coordinates
	if [ "$OUT_H" -lt 360 ] ; then
	    set_this 30 $FRATE
	elif [ "$OUT_H" -lt 450 ] ; then
	    set_this 20 $FRATE
	elif [ "$OUT_H" -lt 480 ] ; then
	    set_this 15 $FRATE
	elif [ "$OUT_H" -gt 720 ] ; then
	    set_this 5 $FRATE
	else 
	    set_this 10 $FRATE
	fi
	VRATE=${THIS}
	if [ ! "${SKIP}" ] ; then
            query_options_stream
	fi
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

##########
    # echo "        Cam: ${CAM_W}x${CAM_H} webcam "
    # echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps "
    # echo "      Audio: ${AC} channel(s) at ${AB}kbps"
    # echo "       File: ${OUTFILE}"
    # 	echo "     ${SAVEDIR}/test_${NAME}.f4v"
    # 	echo "      Stream: ${URL}/${KEY}"
    # echo " Local File: ${FILE}"
    # echo "      Screen: ${GRABAREA} at ${GRABXY} "
    # echo "      webcam: ${CAM_W}x${CAM_H} inset at lowerleft."
