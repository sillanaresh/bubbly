using System;
using System.IO;
using System.Media;
using System.Threading.Tasks;

namespace Bubbly.Windows.Services;

public sealed class BubbleSoundPlayer
{
    public void Play(string presetId, string volumeId)
    {
        if (presetId == "muted")
        {
            return;
        }

        try
        {
            var data = MakeBubbleWav(presetId, VolumeMultiplier(volumeId));
            _ = Task.Run(() =>
            {
                using var stream = new MemoryStream(data);
                using var player = new SoundPlayer(stream);
                player.PlaySync();
            });
        }
        catch
        {
            // Sound should never block the companion interaction.
        }
    }

    private static double VolumeMultiplier(string volumeId)
    {
        return volumeId switch
        {
            "soft" => 0.55,
            "loud" => 1.55,
            _ => 1.0
        };
    }

    private static byte[] MakeBubbleWav(string presetId, double volumeMultiplier)
    {
        const int sampleRate = 44100;
        const double duration = 0.42;
        var sampleCount = (int)(sampleRate * duration);
        using var stream = new MemoryStream();
        using var writer = new BinaryWriter(stream);

        writer.Write("RIFF"u8.ToArray());
        writer.Write(36 + sampleCount * 2);
        writer.Write("WAVE"u8.ToArray());
        writer.Write("fmt "u8.ToArray());
        writer.Write(16);
        writer.Write((short)1);
        writer.Write((short)1);
        writer.Write(sampleRate);
        writer.Write(sampleRate * 2);
        writer.Write((short)2);
        writer.Write((short)16);
        writer.Write("data"u8.ToArray());
        writer.Write(sampleCount * 2);

        for (var frame = 0; frame < sampleCount; frame++)
        {
            var t = (double)frame / sampleRate;
            var softened = Math.Tanh(Signal(presetId, t)) * 0.64 * volumeMultiplier;
            writer.Write((short)(Math.Clamp(softened, -1, 1) * short.MaxValue));
        }

        return stream.ToArray();
    }

    private static double Signal(string presetId, double t)
    {
        return presetId switch
        {
            "softBloop" =>
                Droplet(t, 0.00, 0.20, 280, 430, 0.70) +
                Droplet(t, 0.14, 0.15, 330, 520, 0.32),
            "jellyPop" =>
                Droplet(t, 0.00, 0.09, 340, 220, 0.90) +
                Droplet(t, 0.05, 0.13, 720, 980, 0.40),
            "budak" =>
                Droplet(t, 0.00, 0.07, 190, 140, 1.00) +
                Droplet(t, 0.045, 0.10, 520, 360, 0.54) +
                Droplet(t, 0.12, 0.10, 760, 900, 0.26),
            "bubbleChime" =>
                Droplet(t, 0.00, 0.17, 820, 1220, 0.56) +
                Droplet(t, 0.11, 0.20, 1040, 1460, 0.34),
            _ =>
                Droplet(t, 0.00, 0.13, 610, 980, 0.74) +
                Droplet(t, 0.08, 0.16, 420, 760, 0.42) +
                Droplet(t, 0.19, 0.12, 760, 1180, 0.28)
        };
    }

    private static double Droplet(double t, double start, double duration, double startFrequency, double endFrequency, double gain)
    {
        if (t < start || t > start + duration)
        {
            return 0;
        }

        var progress = (t - start) / duration;
        var frequency = startFrequency + (endFrequency - startFrequency) * progress;
        var envelope = Math.Sin(progress * Math.PI) * Math.Exp(-progress * 2.35);
        var wobble = Math.Sin(2 * Math.PI * 9 * progress) * 0.025;
        return Math.Sin(2 * Math.PI * frequency * (t - start) + wobble) * envelope * gain;
    }
}
