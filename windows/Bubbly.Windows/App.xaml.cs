using System.Net.Http;
using System.Windows;
using Bubbly.Windows.Services;
using Bubbly.Windows.Views;

namespace Bubbly.Windows;

public partial class App : System.Windows.Application
{
    private FloatingPetWindow? _petWindow;
    private SettingsStore? _settingsStore;
    private HttpClient? _httpClient;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        ShutdownMode = ShutdownMode.OnExplicitShutdown;
        _settingsStore = SettingsStore.CreateDefault();
        _httpClient = new HttpClient();
        var settings = _settingsStore.Load();

        _petWindow = new FloatingPetWindow(
            settings,
            _settingsStore,
            new BubbleSoundPlayer(),
            new BubblyChatClient(_httpClient));

        if (settings.IsVisible)
        {
            _petWindow.ShowPet();
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _petWindow?.Dispose();
        _httpClient?.Dispose();
        base.OnExit(e);
    }
}
