namespace zoom_detector;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = Host.CreateApplicationBuilder(args);
        builder.Configuration
            .AddYamlFile("appsettings.yml", false);
        builder.Services.AddOptions<MqttConfig>()
            .Bind(builder.Configuration.GetSection("mqtt"));
        builder.Services.AddHostedService<Worker>();
        var host = builder.Build();
        host.Run();
    }
}