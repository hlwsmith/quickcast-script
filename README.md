# quickcast-script

This is a bash shell script that helps with ffmpeg command line
invocation. It can save a screencast to a file or make a livecast to
YouTube.com or Twitch.tv. Very rough around the edges but perhaps the
source would be useful to others trying to figure out how to use
ffmpeg to stream live content.


## Why This

I would use [Kazam](http://launchpad.net/kazam) for screencasts but
there's no way to adjust the microphone settings. It seems stuck
on 44.1 khz (oh, and the 90's called and wanted their sample rate
back!) Also this can stream live to YouTube or Twitch.

Basically what it does is take a command line like:

`quickcast -g FULL -i 320x240 -m -p lr -S twitchcam`

Constructing and running the actual ffmpeg command (something like):

`ffmpeg -y -loglevel info -f alsa -ar 48000 -i pulse -f x11grab -video_size 1920x1080 -i :0.0+0,0 -f v4l2 -video_size 320x240 -i /dev/video0 -filter_complex "[1:v]scale=896x504,setpts=PTS-STARTPTS[bg]; [2:v]scale=149x111,setpts=PTS-STARTPTS[fg]; [bg][fg]overlay=W-w-4:H-h-4,format=yuv420p[out]" -map [out] -map 0:a -c:a libmp3lame -ac 1 -ab 48k -c:v libx264 -preset veryfast -crf 23 -maxrate 800k -bufsize 1600k -r:v 10 -force_key_frames "expr:if(isnan(prev_forced_t),gte(t,2),gte(t,prev_forced_t+2))" -pix_fmt yuv420p -g 18 -f flv rtmp://live.twitch.tv/app/live_xxxxxxx`

## Requirements

Being just a shell script this calls other command line programs to do
all the real work, so you'll need to make sure they are installed.

- `ffmpeg` I usually build my own using
  [this Compilation Guide](https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu).
  However this script _should_ work with most newer ffmpeg binaries
  packaged with your distro.

- `xwininfo` (in the x11-utils package) which is used to get screen
  and window sizes and placements for screen capturing.

- `v4l2-ctl` (in the v4l-utils package) is handy to have to
  determine your webcam's capabilities and output size information.
  This is optional, just configure the config file with working
  information.
  
- `whiptail` or `dialog` for the UI dialog boxes (I've only tested
  with whiptail but it _should_ work the same with both). However
  you can enter all the parameters on the command line too so this
  is also optional.


## Features

Uses `whiptail` or `dialog` for user text dialog interface. It
_should_ choose the one that's installed automatically
(hopefully). I've **not** actually tested with `dialog` though.

You can avoid the dialogs by supplying the needed information with the
command invocation along with the -S flag (to Skip the final advanced
option screen). Also it will still work all from the command line with
neither `whiptail` or `dialog` installed.


## Examples:

### Webcam capture

I usually use Guvcview or Cheese myself as they offer a visual
monitor of the camera. However this works simply enough if you don't
need that.

- `quickcast.sh camcap` This will pop-up dialog boxes asking for the
  parameters.

- `quickcast.sh -S camcap` This will 'Skip' the dialog boxes and just
  use the defaults, which you can tweak in your ~/.quickcast config
  file

- `quickcast.sh -i 864x480 -S camcap` same but requesting the 864x480
  input size from the camera. The output will be the same size.

### Screen Capturing

- `quickcast.sh -g FULL screencap` Does a screen capture of the full
  screen. Will pop up dialog asking for other parameters, such as the
  output size. More of the defaults should be in the config file, many
  of them are hard coded at the moment.. but hey, it's a shell script
  so it's not THAT hard to alter ;-)

- `quickcast.sh screencap` This will ask you to click on the window
  you want to capture (you can click on the desktop if you want to
  capture the whole thing). You have a chance to alter the coordinates
  too.

### Live Streaming to YouTube

- `quickcast.sh youtube` Pop up dialogues will ask for the details. It
  can get your tube key from the environment variable YOUTUBE_KEY or
  you can keep it in your config file.

- `quickcast.sh -i 864x480 -o 240p -t youtube` -o 240p sets the output
  to YouTube, yea I don't have any uplink. This will also save a local
  .mkv copy. The -t means test so it wont really send the stream to
  YouTube but will also save a local .f4v of what would have been
  sent.

- `quickcast.sh -i 864x480 -o 240p -S youtube` Just like the previous
  example except not a test this time. Skip (-S) any other popup
  dialogues.

### Live Streaming to Twitch

  Twitch mode is like youtube only sends a screencast instead of the
  webcam (and to twitch.tv instead of YouTube.com, obviously).  There
  is also a `twitchcam` mode which insets the output of your webcam
  into the corner of your choice. Like youtube there is also a -t
  option (test) to save the output to a local .fv4 file
  instead. However the twitch mode does not normally save a local .mkv
  copy though, as the youtube mode does. (This is becuase I'm usually
  already working my CPU hard enough playing a game and streaming)

- `quickcast.sh twitch` Will pop up dialogues to query the user for the
  required information. The `twitch` mode doesn't include the webcam
  inset as the `twitchcam` mode does.

- `quickcast.sh -g FULL -i 320x240 -o 720p -S twitchcam` Stream the
  full screen to Twitch adding the webcam insert into the corner
  configured into the coinfig file. The output will be scaled down to
  720p (1280x720) and sent to Twitch. Skip (-S) the pop up dialogues.

## TODO's

- Have a `-D` debug switch that spits put the command line used.

- Allow for more configuration and us less hard-coding of values in the
  script. (Ongoing)

- Make just webcam stream-able to Twitch since they allow all kinds of
  content now, not only gamecasting.

- And make screencasting live stream-able to YouTube.com. 

- Finish making this TODO list, probably will be long!

## The future

First off is mostly testing, fixing the dozens of bugs and improving
the usability.

And further in the future rewriting the whole thing in
[Go](https://golang.org/).

-- Harvey Smith
