using System;
using System.IO;
using System.Text.Json;
using Bubbly.Windows.Models;

namespace Bubbly.Windows.Services;

public sealed class SettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    private readonly string _path;

    public SettingsStore(string path)
    {
        _path = path;
    }

    public static SettingsStore CreateDefault()
    {
        var folder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Bubbly");
        return new SettingsStore(Path.Combine(folder, "settings.json"));
    }

    public BubblySettings Load()
    {
        try
        {
            if (!File.Exists(_path))
            {
                return DefaultSettings();
            }

            var settings = JsonSerializer.Deserialize<BubblySettings>(File.ReadAllText(_path), JsonOptions)
                ?? DefaultSettings();
            settings.Normalize();
            return settings;
        }
        catch
        {
            return DefaultSettings();
        }
    }

    public void Save(BubblySettings settings)
    {
        settings.Normalize();
        var directory = Path.GetDirectoryName(_path);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        File.WriteAllText(_path, JsonSerializer.Serialize(settings, JsonOptions));
    }

    private static BubblySettings DefaultSettings()
    {
        var settings = new BubblySettings();
        settings.Normalize();
        return settings;
    }
}
