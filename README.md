# Zoom Detector

A .NET application to send messages to an MQTT broker when a Zoom meeting starts
and stops on your local machine.  
I use this with my other project,
[pi-ticker](https://github.com/mapitman/pi-ticker), to display messages on a 
[Raspberry Pi](https://www.raspberrypi.org/) with
a [Unicorn HAT HD](https://shop.pimoroni.com/products/unicorn-hat-hd).


## Running in the background

By default the program shows a Spectre.Console spinner and needs a terminal.
Pass `--daemon` (or `-d`) to swap that display for a rolling log file, so the
process can run with no terminal attached.

Each operating system keeps user logs in a different place, so the program
resolves the directory at startup:

| Platform | Log directory |
| --- | --- |
| macOS | `~/Library/Logs/zoom-detector/` |
| Linux | `$XDG_STATE_HOME/zoom-detector/log/`, or `~/.local/state/zoom-detector/log/` |
| Windows | `%LOCALAPPDATA%\zoom-detector\logs\` |

Read the log at any time. On macOS:

```sh
tail -f ~/Library/Logs/zoom-detector/zoom-detector-*.log
```

To put the log somewhere else, set a directory in `appsettings.yml`. The value
expands environment variables:

```yaml
logging:
  directory: /var/log/zoom-detector
```

Log files roll daily, cap at 10 MB each, and the last 14 are kept.

### Install as a background service

Each platform has its own way to start a program at login. The files below are
in the `dist/` directory.

Publish the binary first, and put `appsettings.yml` beside it, because the
program reads that file from its working directory.

```sh
just publish
```

#### macOS

A launch agent runs the program at login without opening a terminal window. A
login item cannot do this, because it starts the program inside a shell
session, which opens a terminal tab and keeps it open.

```sh
mkdir -p ~/.local/bin
cp publish/zoom-detector ~/.local/bin/
cp appsettings.yml ~/.local/bin/
cp dist/local.zoom-detector.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/local.zoom-detector.plist
```

Edit `WorkingDirectory` and `StandardErrorPath` in the plist to match your own
home directory. launchd does not expand `~` or `$HOME` in those two keys.

If you previously ran this as a login item, remove it in System Settings >
General > Login Items. Otherwise both copies run.

```sh
launchctl list | grep zoom-detector
```

The second column is the exit status, where `0` means the last run succeeded.
Startup failures happen before the logger initialises, so they land in
`~/Library/Logs/zoom-detector-launchd.log`.

To remove it:

```sh
launchctl unload ~/Library/LaunchAgents/local.zoom-detector.plist
rm ~/Library/LaunchAgents/local.zoom-detector.plist
```

#### Linux

A systemd user unit runs the program at login. It needs no editing, because
systemd expands `%h` to your home directory.

```sh
mkdir -p ~/.local/bin ~/.config/systemd/user
cp publish/zoom-detector ~/.local/bin/
cp appsettings.yml ~/.local/bin/
cp dist/zoom-detector.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now zoom-detector
```

Check the state, and read startup failures from the journal:

```sh
systemctl --user status zoom-detector
journalctl --user -u zoom-detector -f
```

To keep the program running when you are not logged in, enable lingering:

```sh
loginctl enable-linger "$USER"
```

To remove it:

```sh
systemctl --user disable --now zoom-detector
rm ~/.config/systemd/user/zoom-detector.service
systemctl --user daemon-reload
```

#### Windows

A scheduled task runs the program at logon with no window. A Windows service
is the wrong choice here, because a service runs in session 0, where it cannot
see the Zoom process belonging to the logged-in user.

Copy the published files, then register the task:

```powershell
$dir = "$env:LOCALAPPDATA\Programs\zoom-detector"
New-Item -ItemType Directory -Force -Path $dir
Copy-Item publish\zoom-detector.exe, appsettings.yml -Destination $dir
.\dist\install-windows.ps1
```

The script removes any existing task of the same name, so run it again after
publishing a new build. Pass `-InstallDirectory` to use a different location.

Check the state, and read the log:

```powershell
Get-ScheduledTask -TaskName zoom-detector
Get-Content -Wait "$env:LOCALAPPDATA\zoom-detector\logs\zoom-detector-*.log"
```

To remove it:

```powershell
Unregister-ScheduledTask -TaskName zoom-detector -Confirm:$false
```
