using Bubbly.Windows.Models;
using Bubbly.Windows.Services;
using Xunit;

namespace Bubbly.Windows.Tests;

public sealed class SettingsStoreTests
{
    [Fact]
    public void LoadMissingFileReturnsDefaultsWithDeviceId()
    {
        var path = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"), "settings.json");
        var settings = new SettingsStore(path).Load();

        Assert.True(settings.IsVisible);
        Assert.False(settings.IsPaused);
        Assert.Equal("bubble", settings.CharacterId);
        Assert.Equal("ocean", settings.ThemeId);
        Assert.Equal("happy", settings.MoodId);
        Assert.Equal("chat", settings.FeatureModeId);
        Assert.False(string.IsNullOrWhiteSpace(settings.DeviceId));
    }

    [Fact]
    public void LoadCorruptedFileFallsBackToDefaults()
    {
        var directory = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, "settings.json");
        File.WriteAllText(path, "{ not-json");

        var settings = new SettingsStore(path).Load();

        Assert.Equal("bubble", settings.CharacterId);
        Assert.False(string.IsNullOrWhiteSpace(settings.DeviceId));
    }

    [Fact]
    public void SaveAndLoadRoundTripsSettings()
    {
        var directory = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        var path = Path.Combine(directory, "settings.json");
        var store = new SettingsStore(path);
        var original = new BubblySettings
        {
            IsVisible = false,
            IsPaused = true,
            LastPosition = new SettingPoint(12, 34),
            CharacterId = "puppy",
            ThemeId = "mint",
            MoodId = "focus",
            FeatureModeId = "everything",
            ClickSoundId = "bubbleChime",
            SoundVolumeId = "loud",
            SmartPositioningEnabled = false,
            DeviceId = "device-1"
        };

        store.Save(original);
        var loaded = store.Load();

        Assert.False(loaded.IsVisible);
        Assert.True(loaded.IsPaused);
        Assert.Equal(new SettingPoint(12, 34), loaded.LastPosition);
        Assert.Equal("puppy", loaded.CharacterId);
        Assert.Equal("mint", loaded.ThemeId);
        Assert.Equal("focus", loaded.MoodId);
        Assert.Equal("everything", loaded.FeatureModeId);
        Assert.Equal("bubbleChime", loaded.ClickSoundId);
        Assert.Equal("loud", loaded.SoundVolumeId);
        Assert.False(loaded.SmartPositioningEnabled);
        Assert.Equal("device-1", loaded.DeviceId);
    }

    [Fact]
    public void NormalizeFallsBackUnknownEnumValues()
    {
        var settings = new BubblySettings
        {
            CharacterId = "star",
            ThemeId = "unknown-theme",
            MoodId = "unknown-mood",
            FeatureModeId = "unknown-mode",
            ClickSoundId = "unknown-sound",
            SoundVolumeId = "unknown-volume"
        };

        settings.Normalize();

        Assert.Equal("bubble", settings.CharacterId);
        Assert.Equal("ocean", settings.ThemeId);
        Assert.Equal("happy", settings.MoodId);
        Assert.Equal("chat", settings.FeatureModeId);
        Assert.Equal("waterDrop", settings.ClickSoundId);
        Assert.Equal("normal", settings.SoundVolumeId);
    }
}
