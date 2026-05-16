using System;
using System.Collections.Generic;
using System.Linq;

namespace Bubbly.Windows.Models;

public sealed class BubblySettings
{
    public bool IsVisible { get; set; } = true;
    public bool IsPaused { get; set; }
    public SettingPoint? LastPosition { get; set; }
    public string CharacterId { get; set; } = BubblyIds.DefaultCharacterId;
    public string ThemeId { get; set; } = BubblyIds.DefaultThemeId;
    public string MoodId { get; set; } = BubblyIds.DefaultMoodId;
    public string FeatureModeId { get; set; } = BubblyIds.DefaultFeatureModeId;
    public string ClickSoundId { get; set; } = BubblyIds.DefaultClickSoundId;
    public string SoundVolumeId { get; set; } = BubblyIds.DefaultSoundVolumeId;
    public bool SmartPositioningEnabled { get; set; } = true;
    public string DeviceId { get; set; } = Guid.NewGuid().ToString("N");

    public void Normalize()
    {
        CharacterId = BubblyIds.Normalize(CharacterId, BubblyIds.Characters, BubblyIds.DefaultCharacterId);
        ThemeId = BubblyIds.Normalize(ThemeId, BubblyIds.Themes, BubblyIds.DefaultThemeId);
        MoodId = BubblyIds.Normalize(MoodId, BubblyIds.Moods, BubblyIds.DefaultMoodId);
        FeatureModeId = BubblyIds.Normalize(FeatureModeId, BubblyIds.FeatureModes, BubblyIds.DefaultFeatureModeId);
        ClickSoundId = BubblyIds.Normalize(ClickSoundId, BubblyIds.ClickSounds, BubblyIds.DefaultClickSoundId);
        SoundVolumeId = BubblyIds.Normalize(SoundVolumeId, BubblyIds.SoundVolumes, BubblyIds.DefaultSoundVolumeId);
        if (string.IsNullOrWhiteSpace(DeviceId))
        {
            DeviceId = Guid.NewGuid().ToString("N");
        }
    }
}

public sealed record SettingPoint(double X, double Y);

public static class BubblyIds
{
    public const string DefaultClickSoundId = "waterDrop";
    public const string DefaultSoundVolumeId = "normal";
    public const string DefaultThemeId = "ocean";
    public const string DefaultMoodId = "happy";
    public const string DefaultCharacterId = "bubble";
    public const string DefaultFeatureModeId = "chat";

    public static readonly string[] Characters = ["bubble", "kitten", "puppy"];
    public static readonly string[] Themes = ["ocean", "strawberry", "mint", "sunset", "lavender"];
    public static readonly string[] Moods = ["happy", "sleepy", "shy", "focus"];
    public static readonly string[] FeatureModes = ["carefree", "chat", "playground", "everything"];
    public static readonly string[] EffectActions = ["rain", "cloud", "butterflies", "cannon", "sparkles"];
    public static readonly string[] ClickSounds = ["waterDrop", "softBloop", "jellyPop", "budak", "bubbleChime", "muted"];
    public static readonly string[] SoundVolumes = ["soft", "normal", "loud"];

    public static string Normalize(string? value, IReadOnlyCollection<string> allowed, string fallback)
    {
        return value is not null && allowed.Contains(value) ? value : fallback;
    }

    public static string TitleFor(string id)
    {
        return id switch
        {
            "bubble" => "Bubbly",
            "kitten" => "Cat",
            "puppy" => "Dog",
            "ocean" => "Ocean",
            "strawberry" => "Strawberry",
            "mint" => "Mint",
            "sunset" => "Sunset",
            "lavender" => "Lavender",
            "happy" => "Happy",
            "sleepy" => "Sleepy",
            "shy" => "Shy",
            "focus" => "Focus",
            "carefree" => "Carefree",
            "chat" => "Chatty",
            "playground" => "Playtime",
            "everything" => "Bubbly Max",
            "waterDrop" => "Water Drop",
            "softBloop" => "Soft Bloop",
            "jellyPop" => "Jelly Pop",
            "budak" => "Budak",
            "bubbleChime" => "Bubble Chime",
            "muted" => "No Sound",
            "soft" => "Soft",
            "normal" => "Normal",
            "loud" => "Loud",
            "rain" => "Rain",
            "cloud" => "Cloud",
            "butterflies" => "Butterflies",
            "cannon" => "Cannon",
            "sparkles" => "Sparkles",
            _ => id
        };
    }

    public static IReadOnlyList<string> EnabledActions(string featureModeId)
    {
        return featureModeId switch
        {
            "chat" => ["chat"],
            "playground" => EffectActions,
            "everything" => ["chat", "rain", "cloud", "butterflies", "cannon", "sparkles"],
            _ => []
        };
    }
}
