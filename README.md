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

`just install` publishes the program, copies it into `~/.local/bin`, and
registers the right kind of background service for the platform it runs on:

| Platform | Service |
| --- | --- |
| macOS | a launch agent |
| Linux | a systemd user unit |
| Windows | a scheduled task |

```sh
just install
just status
just logs
```

`just install` never overwrites an existing `appsettings.yml`, because that
file holds your broker address.

Use `just uninstall` to stop and remove the service. The program itself stays
in `~/.local/bin`.

#### What each platform gets

**macOS** gets a launch agent. A login item would not do, because it starts the
program inside a shell session, which opens a terminal window and keeps it
open.

The recipe generates the agent from `dist/local.zoom-detector.plist.template`,
filling in absolute paths for your home directory. launchd does not expand `~`
or `$HOME` in the `WorkingDirectory` and `Standard*Path` keys, so those paths
cannot be written portably. The generated file is not tracked by git.

If `zoom-detector` is still a login item, remove it in System Settings >
General > Login Items, or two copies will run.

**Linux** gets a systemd user unit. It needs no generation step, because
systemd expands `%h` to your home directory.

To keep it running while you are logged out:

```sh
loginctl enable-linger "$USER"
```

**Windows** gets a scheduled task, registered by `dist/install-windows.ps1`. A
Windows service would run in session 0, where it cannot see the Zoom process
belonging to the logged-in user, so detection would never fire.

#### Installing by hand

The recipes above are a convenience. To do it yourself, publish the program,
copy it and `appsettings.yml` into a directory on your path, then use the file
in `dist/` for your platform. The program reads `appsettings.yml` from its
working directory, so those two files must sit together.

## Other recipes

| Recipe | What it does |
| --- | --- |
| `just build` | Compiles for development. |
| `just publish` | Produces the self-contained program in `publish/`. |
| `just run` | Runs in the foreground with the Spectre.Console display. |
| `just run-daemon` | Runs in the foreground writing to the log file. |
| `just stage` | Publishes and copies into `~/.local/bin`, without registering a service. |
| `just clean` | Removes build output. |
