#!/bin/bash

PROGNAME="quickcast.sh"
VERSION="0.7.2"
CONFIGFILE="${HOME}/.quickcast"
DATE=$(date +%Y-%m-%d_%H%M%S)

show_usage() {
USAGE="
USAGE: ${PROGNAME} [options] <stream_type>

If run without options or ${PROGNAME} will use dialog boxes to query
the user for the needed information.

  Options:
      -h
          Output this help
      -b <Audio bitrate>
          The bitrate for the audio encoder in kbps.
          The default is 48*<number of channels> for Twitch streams
          and 64*<number of channels> for everything else.
      -c <Audio_channels>
          The number of audio channels 1 (mono) or 2 (stereo.)
           The default is 1 for Twitch streams and 2 for everthing else.
      -C <CBR>
          The 'constant bit rate' setting for the video in kbps. Note
          that this is not true CBR, the encoder will attempt to
          gravitate toward this setting. Normally one just needs to
          set the maxrate setting, (See -M). This setting overides the
          -M setting.
      -g <screen-capture-dimensions>
          Sets the screen grab capture dimensions of the form
          WIDTHxHEIGHT If omitted it is selected interactively via
          clicking on the desired window. Use the keyword 'full' to
          grab the whole screen (or just click on the desktop).
      -i <input-video-dimensions>
          Size of the input video from the webcam, one of:
            ${CAMSIZES}
          The default is ${DEFAULT_CAMSIZE}. The default and the video
          sizes can be set in the config file.
      -K <streaming-key>
          The streaming key to use for the YouTube or Twitch stream
          (the option is ignored otherwise.) By default the proper key
          is selected from the confog file ${CONFIGFILE} or the
          environment setting.
      -m 
          Match scale. This option will scale the TwitchCam inset
          video down the same amount as the screengrab part is being
          scaled (if any). For example if you're screencasting
          1920x1080 down to 720p (1280x720) and have the webcam inset
          set at 320x240 then with this option it will also scale down
          the same amount (by .667 to 213x160 in this example) and
          without this option the inset will remain at 320x240, perhaps
          taking up more of the video real-estate then you expected.
          This option has no effect in the other modes.
      -M <max-bitrate>
          The max bitrate of the video encoder in kbps, the default depends
          on the stream type. (around 600 for YouTube and Twitch streams)
          Remember to add the audio bitrate to this if you want to determine
          what the final bitrate will be. Overridden by the -C setting
      -o <output-height>
          Sets the output height, where <output-height> is one of:
             240p 360p 450 480p 504 540 576 720p 900 1008 and 1080p
          The width will then be set to a hardcoded (~16x9) dimension
          unless the -s (scale) option is used.
          240p, 360p 480p and 720p could be used to live stream to YouTube.
          The defaults are:
          360p for 'youtube', 504 for the 'twitch' and 'twitchcam'
          streams. For 'screencap' and 'camcap' the input sized is
          used.
      -p <placement>
          The placement of the Webcam inset for twitchcam mode.  One
          of: ll, lr, ul, ur (for lower left, lower right, upper left,
          upper right). This setting is ignore in the other modes. The
          default is taken from the config file, (initially set too
          ll for lower left)
      -Q <quality-preset>
          One of ultrafast, superfast, veryfast, faster, fast, medium,
          slow, slower, veryslow. The default depends on the stream
          type.  Faster is easier on the CPU for a given bitrate though
          the image will be a lower quality. If the fps isn't keeping
          up with the desired number then either 'speed up' this preset,
          or lower the video size. On the other hand if you're not having
          that problem but want better quality then 'slow down' this value.
      -r <vrate>
          The video frame rate. If omitted defaults depends on the output
          video size configuration and mode.
      -R <audio-sample-rate>
          in hz, usually either 44100 or 48000.
      -s
          Scales the output width to the output height, maintaining
          the same ration from the input. Without this option a
          standard (~16x9-ish) width will be used, potentially
          stretching or shrinking the width dimension if the original
          was not also in 16x9.
      -S
          Skip the option dialogs, taking the defaults without querying
          for the information.
      -t
          Test run, does not stream, instead saves what would have
          been streamed to: test_<stream_name>.f4v. This only effects
          the modes that stream to the internet (twitch, twitchcam
          and youtube). This option is ignored for other stream types.
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
echo "$USAGE"
}

set_placement ()
{
    while true; do
	for choice in ll lr ul ur; do
	    if [ "${1}" = "${choice}" ]; then
		break 2
	    fi
	done
	echo "Placement of inset needs to be one of: ll lr ul ur" >&2
	return 1
    done
    case ${1} in
	ll)
	    PLACEMENT="4:H-h-4"
	    CORNER="LowerLeft"
	    ;;
	lr)
	    PLACEMENT="W-w-4:H-h-4"
	    CORNER="LowerRight"
	    ;;
	ul)
	    PLACEMENT="4:4"
	    CORNER="UpperLeft"
	    ;;
	ur)
	    PLACEMENT="W-w-4:4"
	    CORNER="UpperRight"
	    ;;
    esac
}

set_this_wh ()
{
    WxH=${1//x/ }
    THIS_W=$(echo "$WxH" | awk '{print $1}')
    THIS_H=$(echo "$WxH" | awk '{print $2}')
    [ "${THIS_W}" ] && [ "${THIS_H}" ] || return 1
}

set_this ()
# sets THIS to the REQUESTED value or the DEFAULT
{
    DEFAULT=${1}
    REQUESTED=${2}
    if [ "$REQUESTED" ] ; then
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
    if [ ${NEW_H} -gt ${OLD_H} ] ; then
	echo "Scaled height (${NEW_H}) must not be larger then "
	echo "the original (${OLD_H})" >&2
	exit 1
    fi
    NEW_W=$(echo ${OLD_W}*${NEW_H} / ${OLD_H} | bc)
}

get_windowinfo ()
{
    THIS_W=$1
    THIS_H=$2
    if [ "$3" ]; then
	THIS_X=$3
    else
	THIS_X="0"
    fi
    if [ "$4" ];then
	THIS_Y=$4
    else
	THIS_Y="0"
    fi
    echo "Got window info ${THIS_W}x${THIS_H} : ${THIS_X},${THIS_Y}"
}

get_grabarea()
# was do_coordinates ()
{
    # gets the width and height
    if [ ! "$GRAB_W" ] ; then
	echo "Click the mouse on the window you wish to capture"
	WINDOWINFO=$(echo $(xwininfo| awk '/ Width| Height| Corners/{print $2 }') | sed 's|\([0-9]*\) \([0-9]*\) +\([0-9]*\)+\([0-9]*\).*|\1 \2 \3 \4|')
	get_windowinfo $WINDOWINFO
	echo "Clicked window was ${THIS_W}x${THIS_H} "
	read -p "Enter new WIDTHxHEIGHT and/or hit enter to continue. " NEW_WH
	if [ "$NEW_WH" ] ; then
	    set_this_wh $NEW_WH
	fi
	GRAB_W=${THIS_W}
	GRAB_H=${THIS_H}
    fi
    if [ ! "$GRAB_X" ] ; then
	# was do_grabarea()
	# get's top left corner offset from top left of root window
	echo "Top-left corner at ${THIS_X},${THIS_Y}"
	OLD_IFS="$IFS"
	IFS="${IFS},x"
	read -p "Enter new X,Y offset and/or hit enter to continue." NEW_X NEW_Y
	if [ "$NEW_X" ] ; then
	    echo "Got NEW X,Y ${NEW_X},${NEW_Y}"
	    THIS_X="$NEW_X"
	    THIS_Y="$NEW_Y"
	    # was check_size() $THIS_X $THIS_Y
	    let XTOT=THIS_X+GRAB_W
	    if [ $ROOTW -lt $XTOT ] ; then
		let THIS_X=ROOTW-GRAB_W
		echo "XTOT to big at ${XTOT} adjusting X offest to ${THIS_X}"
	    else
		echo "XTOT is good to go at ${XTOT}"
	    fi
	    let YTOT=THIS_Y+GRAB_H
	    if [ $ROOTH -lt $YTOT ] ; then
		let THIS_Y=ROOTH-GRAB_H
		echo "YTOT to big at ${YTOT} adjusting Y offest to ${THIS_Y}"
	    else
		echo "YTOT is good to go at ${YTOT}"
	    fi
	fi
	IFS=${OLD_IFS}
	GRAB_X=${THIS_X}
	GRAB_Y=${THIS_Y}
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
    MIC="-f alsa -ar ${SAMPLES} -i pulse"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -i ${WEBCAM}"
    ACODEC="-c:a $AENCODE -ac ${AC} -ab ${AB}k "
    # just letting the underlying ffmpeg decide on the framerate here
    #VCODEC="-c:v libx264 -preset ${QUALITY} -qp 0 -r:v ${VRATE}"
    VCODEC="-c:v libx264 -r:v ${VRATE} -preset ${QUALITY} -qp 0"
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
	echo "     Stream: ${URL}/${KEY}"
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
    let GOP=VRATE*2-2
    MIC="-f alsa -ar ${SAMPLES} -i pulse"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -i ${WEBCAM}"
    if [ $AENCODE = "libfdk_aac" ]; then
	ACODEC="-c:a $AENCODE -ac ${AC} -ab ${AB}k -bsf:a aac_adtstoasc"
    else
	ACODEC="-c:a $AENCODE -ac ${AC} -ab ${AB}k "
    fi
    VCODEC="-c:v libx264 ${VSIZE} -r:v ${VRATE} -preset ${QUALITY} ${BRATE}"
    OUTFMT="-f tee -map 0:a -map 1:v -flags +global_header"
    OUTPUT="${SAVEDIR}/${OUTFILE}"
    if [ "$TEST" ] ; then
	TEEOUT="${OUTPUT}|${SAVEDIR}/test_${NAME}.f4v"
	echo "Saving to test stream file: ${TEEOUT}"
    else
	TEEOUT="${OUTPUT}|[f=flv]${URL}/${KEY}"
    fi
    $FFMPEG ${MIC} ${CAM} \
	${ACODEC} ${VCODEC} -pix_fmt yuv420p -g ${GOP} \
	${OUTFMT} "${TEEOUT}" 2>${SAVEDIR}/${NAME}.log
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
    echo "     Screen: ${GRABAREA} at ${GRABXY} "
    echo "      Video: ${OUT_W}x${OUT_H} (${QUALITY})"
    echo "      Audio: ${AC} channel(s) at ${SAMPLES} to ${AB}kbps"
    echo "       File: ${OUTFILE}"
    echo " --------------------- "
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    MIC="-f alsa -ar ${SAMPLES} -i pulse"
    SCREEN="-video_size ${GRABAREA} -i :0.0+${GRABXY}"
    ACODEC="-c:a $AENCODE -ac ${AC} -ab ${AB}k"
    VCODEC="-c:v libx264 -preset ${QUALITY} -qp 0 -r:v 15"
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
	echo "      Stream: ${URL}/\${KEY}"
    fi
    echo " --------------------- "
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    # An effort to not go over 2 sec keyframes
    let GOP=VRATE*2-2
    MIC="-f alsa -ar ${SAMPLES} -i pulse"
    SCREEN="-video_size ${GRABAREA} -i :0.0+${GRABXY}"
    ACODEC="-c:a $AENCODE -ac ${AC} -ab ${AB}k"
    VCODEC="-c:v libx264 -preset ${QUALITY} -crf 20 ${BRATE} -r:v ${VRATE}"
    # KFRAMES is another attempt to keep key intervals at 2 seconds
    KFRAMES="expr:if(isnan(prev_forced_t),gte(t,2),gte(t,prev_forced_t+2))"
    FILTER="scale=w=${OUT_W}:h=${OUT_H}"
    if [ "$TEST" ] ; then
	OUTPUT="${SAVEDIR}/test_${NAME}.f4v"
	echo "Saving to test stream file: ${OUTPUT}"
    else
	OUTPUT="${URL}/${KEY}"
    fi
    $FFMPEG ${MIC} -f x11grab ${SCREEN} \
	-filter:v "${FILTER}" \
	${ACODEC} ${VCODEC} \
	-force_key_frames "${KFRAMES}" -pix_fmt yuv420p -g $GOP \
	-f flv "${OUTPUT}" 2>${SAVEDIR}/${NAME}.log
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
    echo " webcam-out: ${CAMO_W}x${CAMO_H} ${MATCHSCALE} inset ${CORNER}."
    echo "      Video: ${OUT_W}x${OUT_H} at ${VRATE}fps (${QUALITY})"
    echo "      Audio: ${AC} channel(s) at ${SAMPLES} to ${AB}kbps"
    if [ "$TEST" ] ; then
	echo "Saving to test stream file: "
	echo "     ${SAVEDIR}/test_${NAME}.f4v"
    else
	echo "      Stream: ${URL}/\${KEY}"
    fi
    echo "      BRATE: ${BRATE}"
    echo " --------------------- "
    echo
    read -p "Hit any key to continue."
    echo " -- Type q + enter to quit. --"
    let GOP=VRATE*2-2
    MIC="-f alsa -ar ${SAMPLES} -i pulse"
    SCREEN="-video_size ${GRABAREA} -i :0.0+${GRABXY}"
    CAM="-f v4l2 -video_size ${CAM_W}x${CAM_H} -i ${WEBCAM}"
    ACODEC="-c:a $AENCODE -ac ${AC} -ab ${AB}k"
    VCODEC="-c:v libx264 -preset ${QUALITY} -crf 23 ${BRATE} -r:v ${VRATE}"
    KFRAMES="expr:if(isnan(prev_forced_t),gte(t,2),gte(t,prev_forced_t+2))"
    # set up overlay filter
    MAIN="[1:v]scale=${OUT_W}x${OUT_H},setpts=PTS-STARTPTS[bg]"
    if [ "${MATCHSCALE}" = scaled ]
    then INSET="[2:v]scale=${CAMO_W}x${CAMO_H},setpts=PTS-STARTPTS[fg]"
    else INSET="[2:v]setpts=PTS-STARTPTS[fg]"
    fi
    OVERLAY="[bg][fg]overlay=${PLACEMENT},format=yuv420p[out]"
    FILTER="${MAIN}; ${INSET}; ${OVERLAY}"
    if [ "$TEST" ] ; then
	OUTPUT="${SAVEDIR}/test_${NAME}.f4v"
	echo "Saving to test stream file: ${OUTPUT}"
    else
	OUTPUT="${URL}/${KEY}"
    fi
    $FFMPEG ${MIC} -f x11grab ${SCREEN} ${CAM} \
	-filter_complex "${FILTER}" -map "[out]" -map 0:a \
	${ACODEC} ${VCODEC} \
	-force_key_frames "${KFRAMES}" -pix_fmt yuv420p -g $GOP \
	-f flv "${OUTPUT}" 2>${SAVEDIR}/${NAME}.log
}

query_webcam ()
# CAMSIZES and DEFAULT_CAMSIZE are set the the config file
{
    MSG=""
    CHECKED=0
    if [ ! -v CAMSIZES ]; then
       CAMSIZES="176x144 640x360 640x480"
       DEFAULT_CAMSIZE=640x480
       MSG="Camera sizes NOT set in config file! "
    fi
    if [ ! "$dialog" ]; then
	if [ ! "$CAM_W" ]; then
	    set_this_wh $DEFAULT_CAMSIZE
	    CAM_W=$THIS_W
	    CAM_H=$THIS_H
	fi
    fi
    menu=$(for s in $CAMSIZES
       do
         ratio=$(echo $s | sed 's|x|/|')
         if [ $s = $DEFAULT_CAMSIZE ]
         then
             if [ ! $CHECKED -eq 1 ]
             then echo $s $(echo "scale=2; $ratio"|bc) ON; CHECKED=1
             else echo $s $(echo "scale=2; $ratio"|bc) OFF
             fi
         else echo $s $(echo "scale=2; $ratio"|bc) OFF
         fi
       done
       )
    if INSIZE=$($dialog --title "Input Video Dimensions" \
	--nocancel --radiolist \
        "${MSG}Choose dimensions for the video camera:" 15 60 8 \
        $menu 3>&1 1>&2 2>&3);
    then
	set_this_wh $INSIZE
	CAM_W=$THIS_W
	CAM_H=$THIS_H
    fi
}

query_outsize_youtube() {
# For use with YouTube 240p 360p 480p 720p
    if OUTSIZE=$($dialog --title "Output Video Dimensions" \
	--nocancel --radiolist \
	"Choose dimensions for the streaming video:" 12 60 4 \
	"240p" "432x240" OFF \
	"360p" "640x360" ON \
	"480p" "864x480" OFF \
	"720p" "1280x720" OFF 3>&1 1>&2 2>&3);
    then
	set_outsize $OUTSIZE
    fi
}

query_outsize_twitch() {
# For use with twitch.tv
#   240p 360p 450 480p 504 540 576 720p 900 1008 and 1080p
    if OUTSIZE=$($dialog --title "Video Encoder Settings" --radiolist \
	"Choose dimensions for the streaming video:" 20 60 8 \
	"240p" "432x240" OFF \
	"360p" "640x360" OFF \
	"450" "800x450" ON \
	"480p" "864x480" OFF \
	"504" "896x504" OFF \
	"540" "960x540" OFF \
	"576" "1024x576" OFF \
	"720p" "1280x720" OFF \
	3>&1 1>&2 2>&3);
    then
	set_outsize $OUTSIZE
    fi
}

query_outsize_screen() {
# For use with screen grabs
#   240p 360p 450 480p 504 540 576 720p 900 1008 and 1080p
    if OUTSIZE=$($dialog --title "Video Encoder Settings" --radiolist \
	"Choose dimensions for the output video:" 18 60 11 \
	"240p" "432x240" OFF \
	"360p" "640x360" OFF \
	"450" "800x450" OFF \
	"480p" "864x480" OFF \
	"504" "896x504" OFF \
	"540" "960x540" OFF \
	"576" "1024x576" OFF \
	"720p" "1280x720" ON \
	"900" "1600x900" OFF \
	"1008" "1792x1008" OFF \
	"1080p" "1920x1080" OFF \
	3>&1 1>&2 2>&3);
    then
	set_outsize $OUTSIZE
    fi
}

query_audio() {
    if [ "$AC" -eq 1 ] ; then
	STAT1=ON
	STAT2=OFF
    else
	STAT1=OFF
	STAT2=ON
    fi
    CHOICE=$($dialog --title "Audio Options" --radiolist --nocancel \
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
    CHOICE=$($dialog --title "Audio Options" --radiolist --nocancel \
	"Choose bitrate in kbps from list:" 10 60 4 \
	"48" "48 kbps " $STAT1 \
	"64" "64 kbps " $STAT2 \
	"96" "96 kbps " $STAT3 \
	"128" "128 kbps " $STAT4 \
	3>&1 1>&2 2>&3)
    AB=$CHOICE
}

query_video() {
    #quality-presets:
    #ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
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
    CHOICE=$($dialog --title "Video Encoder Options" --radiolist \
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

query_stream() {
    #max-bitrate #  600 for YouTube and Twitch
    #streaming-key #
    #stream_url # rtmp://example.com/path
    if CHOICE=$($dialog --title "Stream Settings" --inputbox \
	"Url for the stream?" 10 60 ${URL} \
	3>&1 1>&2 2>&3); then
	URL="$CHOICE"
    else
	echo "Operation Canceled."
	exit
    fi
    if CHOICE=$($dialog --title "Stream Settings" --inputbox \
	"The key for the stream?" 10 60 ${KEY} \
	3>&1 1>&2 2>&3); then
	KEY="$CHOICE"
    else
	echo "Operation Canceled."
	exit
    fi
    if CHOICE=$($dialog --title "Stream Settings" --inputbox \
	"Uplink bandwidth in kbps?" 10 60 ${BANDWIDTH} \
	3>&1 1>&2 2>&3); then
	BANDWIDTH="$CHOICE"
    else
	echo "Operation Canceled."
	exit
    fi
    if $dialog --title "Stream Settings" --yesno --defaultno \
	"Is this a test run" 10 60; then
	TEST=True
    else
	TEST=
    fi
}

query_options_local() {
    if OPTIONS=$($dialog --title "Options" \
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

query_options_stream() {
    if OPTIONS=$($dialog --title "Options" \
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

make_config() {
    echo "Creating config file in ${CONFIGFILE}"
cat > ${CONFIGFILE} <<EOF
# bash source file
# keys for live streaming sites, used by quickcast.sh script
# obviously these can't be posted on github and stuff.

#### Twich.tv
TWITCH_URL="rtmp://live.twitch.tv/app"
# Twich.tv just uses one key
#TWITCHKEY=live_00000000_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWITCHKEY=\$(printenv TWITCH_KEY)
# live_0000000_xxxxxxxxxxxx?bandwidthtest=true

#### YouTube.com
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2"
# youtube now uses one key too
#YOUTUBEKEY=xxxx-xxxx-xxxx-xxxx
YOUTUBEKEY=\$(printenv YOUTUBE_KEY)

#### Other configuration variables

# Perhaps yoy want to test with the system ffmpeg instead of the one
# you built (you DID build your own ffmpeg binary, of course)
# or change the loggin verbosity.
FFMPEG="ffmpeg -y -loglevel info"
#FFMPEG="/usr/bin/ffmpeg -y -loglevel info"

# Tou probably have more uplink then me and should raise this number,
# it's in kilobits/sec
BANDWIDTH="650"

# default webcam to use, usually this is correct
WEBCAM=/dev/video0
# default placement of inset cam in twitchcam mode, one of: ll lr ul ur
# ll (lower left), lr (lower right), up( upper left), ur (upper right)
PLACEMENT=ll

# Please set this!
# Where to save the files.
#SAVEDIR=\${HOME}/quickcasts

# default audio sample rate
SAMPLES=48000
#SAMPLES=44100

# libmp3lame audio encoder is the one more likley to work out of the box.
# In order to get AAC working you'll likely need to build your own
# ffmpeg binary. At any rate uncomment one of the next two lines
AENCODE=libmp3lame
#AENCODE=libfdk_aac

# If you have v4l2-ctl (found in the v4l-utils package in Debian) you
# run this command to figure out the sizes your webcam supports.
#  v4l2-ctl --list-formats-ext | grep Size: | awk '{print \$3}' | sort -n| uniq
# List which of those you might actually want to use here seporated by space:
# (don't forget the small sizes for the twitchcam inset)
CAMSIZES="160x120 176x144 320x240 352x288 432x240 640x360 640x480 800x600 864x480 1024x576 1280x720"

# Default input video size to use, obviously one from the previous list
DEFAULT_CAMSIZE=640x480

EOF
}

check_config() {
    if [ ! -s "${CONFIGFILE}" ]; then
	make_config
    fi
    source "${CONFIGFILE}"
    if [ ! "${SAVEDIR}" ]; then
	echo -e "Please set a SAVEDIR in your config file:\n ${CONFIGFILE}"
	echo "Then try again."
	exit 1
    fi
    if [ ! -d "${SAVEDIR}" ]; then
	echo -e "Please set a valid SAVEDIR in your config file:\n ${CONFIGFILE}"
	exit 1
    fi
}

check_dialog() {
    # check whether whiptail or dialog is installed
    # (choosing the whiptail if both are found)
    if [ ! "$SKIP" ]; then
	read dialog <<< "$(basename $(which whiptail dialog) 2> /dev/null)"
	echo "Got $dialog for the dialog backend"
	# set the SKIP dialogs flag if none found
	# the user could also set this on the command line
	[[ "$dialog" ]] || {
	    SKIP=True
	}
    fi
}

#### main ####

## init stuff

# get the size of the root window
ROOTSCRN=$(xwininfo -root | awk '/-geo/{print $2}' | sed 's|\([0-9]*\)x\([0-9]*\).*|\1 \2|')
get_windowinfo ${ROOTSCRN}
ROOTW=$THIS_W
ROOTH=$THIS_H

STREAM_TYPES="camcap youtube screencap twitch twitchcam"
declare -A STREAM_DESCS
STREAM_DESCS[camcap]="    - Capture the webcam and save locally."
STREAM_DESCS[youtube]="   - Same as 'camcap' but stream it to YouTube.com too."
STREAM_DESCS[screencap]=" - Grab part of the screen and save locally."
STREAM_DESCS[twitch]="    - Grab part of the screen and stream to Twitch.tv."
STREAM_DESCS[twitchcam]=" - Same as 'twitch' with cam inset at lower left."

check_config

# why can't I put this option parsing into a fucntion?
while getopts ":Vhb:c:C:f:g:i:K:mM:o:p:Q:r:R:sStU:v:x:y:" opt; do
    case $opt in
	V)
	    echo "${PROGNAME} ${VERSION}"
	    exit 0
	    ;;
	h)
	    show_usage
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
	    if [ "$OPTARG" = "full" ]; then
		GRABSIZE=${ROOTW}x${ROOTH}
		GRAB_X=0
		GRAB_Y=0
		echo "GRABSIZE $GRABSIZE"
	    else
		GRABSIZE=$OPTARG
	    fi
	    if ! set_this_wh $GRABSIZE; then
	       echo "Grab size takes the form DDDxDDD";
	       exit 1
	    fi
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
	m)
	    MATCHSCALE=scaled
	    ;;
	M)
	    MAXRATE=$OPTARG
	    ;;
	o)
	    OUTSIZE=$OPTARG
	    ;;
	p)
	    CORNER=$OPTARG
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

check_dialog
echo ${VERSION}

if [[ ! ($1 || $SKIP) ]]; then
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

## the MAIN case ##

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
	get_grabarea
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
	    BRATE="-maxrate ${BANDWIDTH}k -bufsize $((BANDWIDTH*2))k"
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
	    query_outsize_youtube
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
	elif [ "${SKIP}" ]; then
	    echo GOT SKIP
	else
	    query_outsize_twitch
	fi
	if [ ! "$OUTSIZE" ] ; then
	    ### TODO make this a config setting
	    set_outsize 504
	fi
	get_grabarea
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
	[ "${CORNER}" ] || CORNER=${PLACEMENT}
	set_placement ${CORNER} || exit 1
	if [ "${MATCHSCALE}" = scaled ]; then
	    SCALE=$(echo "1000* ${OUT_H} / ${GRAB_H}" | bc)
	    CAMO_W=$(echo "${CAM_W} * ${SCALE} / 1000" | bc)
	    CAMO_H=$(echo "${CAM_H} * ${SCALE} / 1000" | bc)
	else
	    CAMO_W=${CAM_W}
	    CAMO_H=${CAM_H}
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
exit
