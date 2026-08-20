# Where the published program and its appsettings.yml are installed.
install_dir := home_directory() / ".local/bin"

# Show the available recipes.
default:
	@just --list

# Compile for development.
build:
	dotnet build

# Produce the self-contained single-file program in publish/.
publish:
	dotnet publish -c Release -o publish -p:PublishReadyToRun=true -p:PublishSingleFile=true --self-contained true -p:IncludeNativeLibrariesForSelfExtract=true

# Run in the foreground with the Spectre.Console display.
run:
	dotnet run

# Run in the foreground writing to the log file, as the service does.
run-daemon:
	dotnet run -- --daemon

# Remove build output.
clean:
	dotnet clean
	rm -rf publish

# Publish, then copy the program and its settings into place.
stage: publish
	#!/usr/bin/env bash
	set -euo pipefail

	mkdir -p "{{ install_dir }}"
	cp publish/zoom-detector "{{ install_dir }}/"

	# The program reads appsettings.yml from its working directory. Never
	# overwrite an existing one, because it holds the broker address.
	if [ -f "{{ install_dir }}/appsettings.yml" ]; then
		echo "Kept the existing {{ install_dir }}/appsettings.yml"
	else
		cp appsettings.yml "{{ install_dir }}/"
		echo "Copied appsettings.yml. Set your MQTT broker host in it."
	fi

	echo "Staged in {{ install_dir }}"

# Publish, stage, and register the background service for this platform.
install: stage (_install-service os())
	@just --quiet status

[private]
_install-service os:
	#!/usr/bin/env bash
	set -euo pipefail

	case "{{ os }}" in
		macos)   just --quiet _install-macos ;;
		linux)   just --quiet _install-linux ;;
		windows) just --quiet _install-windows ;;
		*)
			echo "No service definition for '{{ os }}'." >&2
			echo "The program is staged in {{ install_dir }}; start it with --daemon." >&2
			exit 1
			;;
	esac

# Generate the launch agent from the template and load it.
[private]
_install-macos:
	#!/usr/bin/env bash
	set -euo pipefail

	agent="{{ home_directory() }}/Library/LaunchAgents/local.zoom-detector.plist"

	# launchd does not expand ~ or $HOME in WorkingDirectory or in the
	# Standard*Path keys, so the paths have to be written in full.
	sed -e "s|__INSTALL_DIR__|{{ install_dir }}|g" \
		-e "s|__HOME__|{{ home_directory() }}|g" \
		dist/local.zoom-detector.plist.template > dist/local.zoom-detector.plist

	plutil -lint dist/local.zoom-detector.plist

	# Unload first, or launchd keeps serving the previous definition.
	launchctl unload "$agent" 2>/dev/null || true
	cp dist/local.zoom-detector.plist "$agent"
	launchctl load "$agent"

	echo "Loaded local.zoom-detector"

# Install the systemd user unit and start it.
[private]
_install-linux:
	#!/usr/bin/env bash
	set -euo pipefail

	unit_dir="{{ home_directory() }}/.config/systemd/user"
	mkdir -p "$unit_dir"
	cp dist/zoom-detector.service "$unit_dir/"
	systemctl --user daemon-reload
	systemctl --user enable --now zoom-detector
	echo "Enabled zoom-detector.service"
	echo
	echo "To keep it running while logged out: loginctl enable-linger \"$USER\""

# Register the scheduled task.
[private]
_install-windows:
	@pwsh -NoProfile -File dist/install-windows.ps1 -InstallDirectory "{{ install_dir }}"

# Show whether the service is registered, and its last result.
status:
	@just --quiet _status "{{ os() }}"

[private]
_status os:
	#!/usr/bin/env bash
	set -euo pipefail

	case "{{ os }}" in
		macos)
			launchctl list | grep zoom-detector \
				|| echo "Not loaded. Install it with: just install"
			;;
		linux)
			systemctl --user status zoom-detector --no-pager || true
			;;
		windows)
			pwsh -NoProfile -Command 'Get-ScheduledTask -TaskName zoom-detector'
			;;
		*)
			echo "No service to check on '{{ os }}'."
			;;
	esac

# Follow the log file.
logs:
	@just --quiet _logs "{{ os() }}"

[private]
_logs os:
	#!/usr/bin/env bash
	set -euo pipefail

	case "{{ os }}" in
		macos)   dir="{{ home_directory() }}/Library/Logs/zoom-detector" ;;
		linux)   dir="${XDG_STATE_HOME:-{{ home_directory() }}/.local/state}/zoom-detector/log" ;;
		windows) dir="$LOCALAPPDATA/zoom-detector/logs" ;;
		*)       echo "Unknown platform." >&2; exit 1 ;;
	esac

	if ! compgen -G "$dir"/*.log >/dev/null; then
		echo "No log files in $dir yet." >&2
		echo "The service writes one once it starts in daemon mode." >&2
		exit 1
	fi

	tail -f "$dir"/*.log

# Stop and remove the background service.
uninstall:
	@just --quiet _uninstall "{{ os() }}"

[private]
_uninstall os:
	#!/usr/bin/env bash
	set -euo pipefail

	case "{{ os }}" in
		macos)
			agent="{{ home_directory() }}/Library/LaunchAgents/local.zoom-detector.plist"
			launchctl unload "$agent" 2>/dev/null || true
			rm -f "$agent"
			echo "Removed the launch agent."
			;;
		linux)
			systemctl --user disable --now zoom-detector || true
			rm -f "{{ home_directory() }}/.config/systemd/user/zoom-detector.service"
			systemctl --user daemon-reload
			echo "Removed the systemd unit."
			;;
		windows)
			pwsh -NoProfile -Command 'Unregister-ScheduledTask -TaskName zoom-detector -Confirm:$false'
			echo "Removed the scheduled task."
			;;
	esac

	echo "The program is still in {{ install_dir }}."
