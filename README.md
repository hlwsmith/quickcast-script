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

## The future

In the future I plan to add support for the 'dialog' backend and let
the script determine which one is installed to use the proper one
('whiptail' or 'dialog').

And further in the future rewrite the whole thing in
[Go](https://golang.org/).

-- Harvey Smith
