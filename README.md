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
back!)

Also in theory you can stream live to YouTube or Twitch using this,
though I've not tested Twitch at all recently. My uplink is horrible
so it is hard to actually test this aspect.

## New feature

This now uses whiptail for a dialog type of text user interface. I
think whiptail is installed by default of Debian based systems (or do
apt-get install whiptail).

You can avoid the dialogs by supplying ALL the needed information with
the command invocation along with the -S flag (to Skip the final
advanced option screen).

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

## The future

First off is mostly testing, fixing the dozens of bugs and improving
the usability.

And further in the future rewriting the whole thing in
[Go](https://golang.org/).

-- Harvey Smith
