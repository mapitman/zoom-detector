using System.Diagnostics;
using System.Net.Mqtt;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Spectre.Console;

namespace zoom_detector;

public class Worker( IOptions<MqttConfig> mqttConfigOptions)
    : BackgroundService
{
    private readonly string _host = mqttConfigOptions.Value.Host;
    private IMqttClient? _client;
    DateTimeOffset _lastDatePrinted = DateTimeOffset.MinValue;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await AnsiConsole.Status().Spinner(Spinner.Known.Dots).StartAsync("Monitoring for Zoom meetings...", async context =>
        {
            context.SpinnerStyle(Style.Parse("green"));
            Console.CancelKeyPress += async (_, _) =>
            {
                context.Status("Stopping...");
                context.SpinnerStyle(Style.Parse("red"));
                await SendClearMessageAsync();
                _client?.Dispose();
            };
        
            var previousMeetingState = MeetingState.NotRunning;
            var firstRun = true;
            _client = await MqttClient.CreateAsync(_host, new MqttConfiguration());
            await _client.ConnectAsync();

            await SendInitialMessageAsync();
            while (!stoppingToken.IsCancellationRequested)
            {
                var isMeetingRunning = ZoomService.IsMeetingRunning();
                if ((firstRun || previousMeetingState == MeetingState.NotRunning) && isMeetingRunning)
                {
                    firstRun = false;
                    previousMeetingState = MeetingState.Running;
                    LogMarkup("[red]In a meeting[/]");
                    await SendMeetingRunningMessageAsync();
                }
                else if (firstRun || previousMeetingState == MeetingState.Running && !isMeetingRunning)
                {
                    firstRun = false;
                    previousMeetingState = MeetingState.NotRunning;
                    LogMarkup("[green]Free[/]");
                    await SendClearMessageAsync();
                }
            
                await Task.Delay(5000, stoppingToken);
            }

            await SendClearMessageAsync();
            _client?.Dispose();
        });
        
    }

    private async Task SendMeetingRunningMessageAsync()
    {
        var payload = new Dictionary<string, string>();
        payload.Add("bg_color", "red");
        payload.Add("text", "On a Call");
        await PublishMessageAsync(payload);
    }

    private async Task SendInitialMessageAsync()
    {
        const string text = "Monitoring for Zoom Meetings";
        var payload = new Dictionary<string, string>();
        payload.Add("bg_color", "green");
        payload.Add("text", text);
        await PublishMessageAsync(payload);
        await Task.Delay(2000);
        await SendClearMessageAsync();
    }

    private async Task SendClearMessageAsync()
    {
        var payload = new Dictionary<string, string> { { "command", "stop" } };
        var message = new MqttApplicationMessage("/ticker1", Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload)));
        if (_client != null) await _client.PublishAsync(message, MqttQualityOfService.ExactlyOnce, false);
    }

    private async Task PublishMessageAsync(Dictionary<string, string> payload)
    {
        var message = new MqttApplicationMessage("/ticker1", Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload)));
        Debug.Assert(_client != null, nameof(_client) + " != null");
        if (_client != null) await _client.PublishAsync(message, MqttQualityOfService.ExactlyOnce, false);
    }
    
    private void LogMarkup(string markup)
    {
        var now = DateTimeOffset.Now;
        if (_lastDatePrinted.Day != now.Day)
        {
            AnsiConsole.MarkupLine($"[bold]{now:yyyy-MM-dd ddd}[/]");
            _lastDatePrinted = now;
        }
        
        AnsiConsole.MarkupLine($"{now:HH:mm:ss} - {markup}");
    }
}