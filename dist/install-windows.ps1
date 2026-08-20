<#
.SYNOPSIS
    Registers zoom-detector to run at logon as a hidden background task.

.DESCRIPTION
    Registers a scheduled task that starts at logon. The task runs in the
    user's own session with an interactive token, which is what lets it see the
    Zoom process it needs to detect.

    The task runs with no window. Output goes to the program's own rolling log
    file under %LOCALAPPDATA%\zoom-detector\logs.

.EXAMPLE
    .\install-windows.ps1

.EXAMPLE
    .\install-windows.ps1 -InstallDirectory 'D:\tools\zoom-detector'
#>
[CmdletBinding()]
param(
    # Directory holding zoom-detector.exe and appsettings.yml.
    [string] $InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs\zoom-detector'),

    [string] $TaskName = 'zoom-detector'
)

$ErrorActionPreference = 'Stop'

$exe = Join-Path $InstallDirectory 'zoom-detector.exe'
if (-not (Test-Path $exe)) {
    throw "zoom-detector.exe not found at $exe. Publish it and copy it there first."
}

# The program reads appsettings.yml from its working directory.
$settings = Join-Path $InstallDirectory 'appsettings.yml'
if (-not (Test-Path $settings)) {
    throw "appsettings.yml not found at $settings. It must sit beside the executable."
}

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Removing the existing '$TaskName' task."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$action = New-ScheduledTaskAction `
    -Execute $exe `
    -Argument '--daemon' `
    -WorkingDirectory $InstallDirectory

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# An interactive token in the user's session, which is what lets the task see
# the user's Zoom process. Limited privileges are enough for that.
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

$settingsSet = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settingsSet `
    -Description 'Publishes Zoom meeting state to an MQTT broker.' | Out-Null

# Confirm the working directory was recorded. The program reads
# appsettings.yml from it, so a blank value means the task will fail at
# startup rather than run with the wrong config.
$registered = (Get-ScheduledTask -TaskName $TaskName).Actions[0]
if ([string]::IsNullOrWhiteSpace($registered.WorkingDirectory)) {
    Write-Warning ("The task registered without a working directory. " +
        "zoom-detector will not find appsettings.yml. Set 'Start in' to " +
        "$InstallDirectory in Task Scheduler, or run the task from that " +
        "directory.")
}

Write-Host "Registered the '$TaskName' task. Starting it now."
Start-ScheduledTask -TaskName $TaskName

Write-Host ''
Write-Host 'Check the state with:'
Write-Host "    Get-ScheduledTask -TaskName $TaskName"
Write-Host ''
Write-Host 'Read the log with:'
Write-Host '    Get-Content -Wait "$env:LOCALAPPDATA\zoom-detector\logs\zoom-detector-*.log"'
