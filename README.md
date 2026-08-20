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

**macOS** gets a launch agent, which launchd starts at login with no terminal
attached.

The recipe generates the agent from `dist/local.zoom-detector.plist.template`,
filling in absolute paths for your home directory. The `WorkingDirectory` and
`Standard*Path` keys take literal paths, so the recipe writes them out in full
for the account it runs under. Git ignores the generated file.

**Linux** gets a systemd user unit, copied straight into place. systemd
expands `%h` to your home directory, so the file works as it ships.

To keep it running while you are logged out:

```sh
loginctl enable-linger "$USER"
```

**Windows** gets a scheduled task, registered by `dist/install-windows.ps1`.
The task runs in your own session with an interactive token, which is what lets
it see the Zoom process it detects.

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
