# Zoom Detector

A .NET application to send messages to an MQTT broker when a Zoom meeting starts
and stops on your local machine.  
I use this with my other project,
[pi-ticker](https://github.com/mapitman/pi-ticker), to display messages on a 
[Raspberry Pi](https://www.raspberrypi.org/) with
a [Unicorn HAT HD](https://shop.pimoroni.com/products/unicorn-hat-hd).


## Running in the background on macOS

By default the program shows a Spectre.Console spinner and needs a terminal.
Pass `--daemon` (or `-d`) to swap that display for a rolling log file at
`~/Library/Logs/zoom-detector/`, so the process can run with no terminal
attached.

Read the log at any time:

```sh
tail -f ~/Library/Logs/zoom-detector/zoom-detector-*.log
```

Log files roll daily, cap at 10 MB each, and the last 14 are kept.

### Install as a launch agent

A launch agent runs the program at login without opening a terminal window. A
macOS login item cannot do this, because it starts the program inside a shell
session and so opens a terminal tab.

Publish the binary and put it on your path:

```sh
just publish
mkdir -p ~/.local/bin
cp publish/zoom-detector ~/.local/bin/
cp appsettings.yml ~/.local/bin/
```

The program reads `appsettings.yml` from its working directory, so that file
must sit beside the binary.

Install the agent:

```sh
cp local.zoom-detector.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/local.zoom-detector.plist
```

The plist hard-codes `/Users/mark.pitman` in its `WorkingDirectory` and
`StandardErrorPath`. Change both to your own home directory, because launchd
does not expand `~` or `$HOME` in those two keys.

If you previously ran this as a login item, remove it in System Settings ›
General › Login Items. Otherwise both copies run.

Check that it started:

```sh
launchctl list | grep zoom-detector
tail -f ~/Library/Logs/zoom-detector/zoom-detector-*.log
```

The second column of the `launchctl list` output is the exit status, where `0`
means the last run succeeded.

Startup failures happen before the logger initialises, so they land in a
separate file:

```sh
cat ~/Library/Logs/zoom-detector-launchd.log
```

To stop and remove the agent:

```sh
launchctl unload ~/Library/LaunchAgents/local.zoom-detector.plist
rm ~/Library/LaunchAgents/local.zoom-detector.plist
```
