using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Windows.Threading;
using Bubbly.Windows.Models;
using Bubbly.Windows.Services;
using Drawing = System.Drawing;
using Forms = System.Windows.Forms;
using MediaColor = System.Windows.Media.Color;
using WpfButton = System.Windows.Controls.Button;
using WpfPoint = System.Windows.Point;

namespace Bubbly.Windows.Views;

public sealed class FloatingPetWindow : Window, IDisposable
{
    private const double WindowSide = 144;
    private const double BodySide = 132;
    private readonly BubblySettings _settings;
    private readonly SettingsStore _settingsStore;
    private readonly BubbleSoundPlayer _soundPlayer;
    private readonly BubblyChatClient _chatClient;
    private readonly WanderPlanner _wanderPlanner = new();
    private readonly DispatcherTimer _animationTimer = new() { Interval = TimeSpan.FromMilliseconds(125) };
    private readonly DispatcherTimer _movementTimer = new() { Interval = TimeSpan.FromSeconds(1.0 / 30.0) };
    private readonly Canvas _root = new() { Width = WindowSide, Height = WindowSide, Background = Brushes.Transparent };
    private readonly Forms.NotifyIcon _notifyIcon;
    private readonly Random _random = new();

    private DispatcherTimer? _restTimer;
    private WanderMotion? _wanderMotion;
    private DateTimeOffset _lastPositionSave = DateTimeOffset.MinValue;
    private ChatWindow? _chatWindow;
    private bool _isPinnedForChat;
    private bool? _pauseStateBeforeChat;
    private bool _isDragging;
    private bool _didDrag;
    private bool _isDisposed;
    private WpfPoint _dragStartScreen;
    private double _dragStartLeft;
    private double _dragStartTop;
    private DateTimeOffset _popUntil = DateTimeOffset.MinValue;

    public FloatingPetWindow(
        BubblySettings settings,
        SettingsStore settingsStore,
        BubbleSoundPlayer soundPlayer,
        BubblyChatClient chatClient)
    {
        _settings = settings;
        _settingsStore = settingsStore;
        _soundPlayer = soundPlayer;
        _chatClient = chatClient;

        Width = WindowSide;
        Height = WindowSide;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        Content = _root;

        PreviewMouseLeftButtonDown += HandleLeftButtonDown;
        PreviewMouseMove += HandleMouseMove;
        PreviewMouseLeftButtonUp += HandleLeftButtonUp;
        MouseRightButtonUp += (_, _) =>
        {
            var menu = BuildPetContextMenu();
            menu.PlacementTarget = this;
            menu.IsOpen = true;
        };

        _animationTimer.Tick += (_, _) => Render();
        _movementTimer.Tick += (_, _) => TickMovement();

        _notifyIcon = new Forms.NotifyIcon
        {
            Text = "Bubbly",
            Icon = CreateTrayIcon(),
            Visible = true,
            ContextMenuStrip = BuildTrayMenu()
        };
        _notifyIcon.MouseClick += (_, args) =>
        {
            if (args.Button == Forms.MouseButtons.Left)
            {
                if (_settings.IsVisible) HidePet(); else ShowPet();
            }
        };

        Render();
    }

    public void ShowPet()
    {
        ApplySavedOrDefaultPosition();
        _settings.IsVisible = true;
        Show();
        Topmost = true;
        EnsureVisible();
        SaveSettings();
        RefreshTrayMenu();
        if (!_settings.IsPaused)
        {
            StartMovement();
        }
    }

    public void HidePet()
    {
        _settings.IsVisible = false;
        CloseChat();
        Hide();
        StopMovement();
        SaveSettings();
        RefreshTrayMenu();
    }

    public void Dispose()
    {
        if (_isDisposed)
        {
            return;
        }

        _isDisposed = true;
        StopMovement();
        _animationTimer.Stop();
        _chatWindow?.Close();
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        _animationTimer.Start();
    }

    private void Render()
    {
        _root.Children.Clear();

        var now = DateTimeOffset.UtcNow;
        var mood = MoodProfile.For(_settings.MoodId);
        var breath = _settings.IsPaused ? 1 : 1 + Math.Sin(now.ToUnixTimeMilliseconds() / 1000.0 * mood.BreathRate) * mood.BreathAmount;
        var bob = _settings.IsPaused ? 0 : Math.Sin(now.ToUnixTimeMilliseconds() / 1000.0 * mood.BobRate) * mood.BobAmount;
        var pop = now < _popUntil;
        var scaleX = breath * (pop ? 1.08 : 1.0);
        var scaleY = (2 - breath) * (pop ? 0.94 : 1.0);

        var body = CreateCharacterVisual(now, mood);
        body.Width = BodySide;
        body.Height = BodySide;
        body.RenderTransformOrigin = new WpfPoint(0.5, 0.5);
        body.RenderTransform = new TransformGroup
        {
            Children =
            {
                new ScaleTransform(scaleX, scaleY),
                new TranslateTransform(0, bob)
            }
        };
        body.Opacity = _settings.IsPaused ? 0.74 : 1.0;
        Canvas.SetLeft(body, 6);
        Canvas.SetTop(body, 6);
        _root.Children.Add(body);

        if (_settings.IsPaused)
        {
            AddBadge("||", "Paused", 44, -46, TogglePause);
        }

        foreach (var action in BubblyIds.EnabledActions(_settings.FeatureModeId))
        {
            var (x, y) = BadgeOffset(action, _settings.CharacterId);
            var label = action switch
            {
                "chat" => _chatWindow is null ? "C" : "..",
                "rain" => "R",
                "cloud" => "Cl",
                "butterflies" => "B",
                "cannon" => "Bo",
                "sparkles" => "*",
                _ => "?"
            };
            AddBadge(label, BubblyIds.TitleFor(action), x, y, () => TriggerAction(action));
        }
    }

    private FrameworkElement CreateCharacterVisual(DateTimeOffset now, MoodProfile mood)
    {
        if (_settings.CharacterId is "kitten" or "puppy")
        {
            return new Image
            {
                Source = new BitmapImage(new Uri($"pack://application:,,,/Assets/{(_settings.CharacterId == "kitten" ? "baby-cat" : "baby-dog")}.png")),
                Stretch = Stretch.Uniform,
                SnapsToDevicePixels = true
            };
        }

        var canvas = new Canvas { Width = BodySide, Height = BodySide };
        var colors = ThemeProfile.For(_settings.ThemeId);
        var fill = new RadialGradientBrush
        {
            GradientOrigin = new WpfPoint(0.23, 0.18),
            Center = new WpfPoint(0.35, 0.28),
            RadiusX = 0.72,
            RadiusY = 0.72
        };
        fill.GradientStops.Add(new GradientStop(colors.Highlight, 0));
        fill.GradientStops.Add(new GradientStop(colors.Mid, 0.52));
        fill.GradientStops.Add(new GradientStop(colors.Deep, 1));

        canvas.Children.Add(new Ellipse
        {
            Width = BodySide,
            Height = BodySide,
            Fill = fill,
            Stroke = new SolidColorBrush(Color.FromArgb(142, 255, 255, 255)),
            StrokeThickness = 4
        });

        AddShape(canvas, new Ellipse
        {
            Width = 46,
            Height = 30,
            Fill = new SolidColorBrush(Color.FromArgb(108, 255, 255, 255))
        }, 28, 25);

        var blinkHeight = _settings.IsPaused ? 14 : mood.EyeHeight(now);
        AddEye(canvas, 43, 48, blinkHeight);
        AddEye(canvas, 76, 48, blinkHeight);
        AddShape(canvas, new Ellipse { Width = 18, Height = 12, Fill = new SolidColorBrush(Color.FromArgb(86, 255, 112, 163)) }, 33, 82);
        AddShape(canvas, new Ellipse { Width = 18, Height = 12, Fill = new SolidColorBrush(Color.FromArgb(86, 255, 112, 163)) }, 82, 82);
        AddShape(canvas, new Path
        {
            Data = Geometry.Parse($"M {51 + mood.SmileOffsetX},85 Q 66, {85 + mood.SmileDepth} {81 + mood.SmileOffsetX},85"),
            Stroke = new SolidColorBrush(Color.FromArgb(224, 20, 43, 71)),
            StrokeThickness = 4,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
            Fill = Brushes.Transparent
        }, 0, 0);

        return canvas;
    }

    private static void AddEye(Canvas canvas, double x, double y, double height)
    {
        AddShape(canvas, new Border
        {
            Width = 14,
            Height = height,
            CornerRadius = new CornerRadius(7),
            Background = new SolidColorBrush(Color.FromRgb(15, 33, 56))
        }, x, y + (19 - height) / 2);
        if (height > 8)
        {
            AddShape(canvas, new Ellipse { Width = 4, Height = 4, Fill = Brushes.White }, x + 3, y + 3);
        }
    }

    private static void AddShape(Canvas canvas, UIElement shape, double left, double top)
    {
        Canvas.SetLeft(shape, left);
        Canvas.SetTop(shape, top);
        canvas.Children.Add(shape);
    }

    private void AddBadge(string label, string tooltip, double offsetX, double offsetY, Action action)
    {
        var button = new WpfButton
        {
            Width = 34,
            Height = 34,
            Padding = new Thickness(0),
            BorderThickness = new Thickness(0),
            Background = Brushes.Transparent,
            ToolTip = tooltip,
            Content = new Grid
            {
                Children =
                {
                    new Ellipse { Fill = new SolidColorBrush(Color.FromArgb(240, 255, 255, 255)) },
                    new TextBlock
                    {
                        Text = label,
                        FontSize = label.Length > 1 ? 10 : 15,
                        FontWeight = FontWeights.Bold,
                        Foreground = new SolidColorBrush(Color.FromRgb(54, 107, 157)),
                        HorizontalAlignment = HorizontalAlignment.Center,
                        VerticalAlignment = VerticalAlignment.Center
                    }
                }
            }
        };
        button.Click += (_, args) =>
        {
            args.Handled = true;
            action();
        };

        Canvas.SetLeft(button, WindowSide / 2 - 17 + offsetX);
        Canvas.SetTop(button, WindowSide / 2 - 17 + offsetY);
        _root.Children.Add(button);
    }

    private static (double X, double Y) BadgeOffset(string action, string characterId)
    {
        if (characterId is "kitten" or "puppy")
        {
            return action switch
            {
                "chat" => (0, -54),
                "rain" => (-58, -20),
                "cloud" => (-58, 24),
                "butterflies" => (-30, 56),
                "cannon" => (30, 56),
                "sparkles" => (58, 24),
                _ => (0, 0)
            };
        }

        return action switch
        {
            "chat" => (45, -47),
            "rain" => (-45, -47),
            "cloud" => (-61, 0),
            "butterflies" => (-42, 49),
            "cannon" => (42, 49),
            "sparkles" => (61, 0),
            _ => (0, 0)
        };
    }

    private void HandleLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (FindAncestor<Button>(e.OriginalSource as DependencyObject) is not null)
        {
            return;
        }

        if (e.ClickCount >= 2)
        {
            TogglePause();
            e.Handled = true;
            return;
        }

        _isDragging = true;
        _didDrag = false;
        _dragStartScreen = PointToScreen(e.GetPosition(this));
        _dragStartLeft = Left;
        _dragStartTop = Top;
        CaptureMouse();
    }

    private static T? FindAncestor<T>(DependencyObject? source) where T : DependencyObject
    {
        while (source is not null)
        {
            if (source is T match)
            {
                return match;
            }

            source = VisualTreeHelper.GetParent(source);
        }

        return null;
    }

    private void HandleMouseMove(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (!_isDragging || e.LeftButton != MouseButtonState.Pressed)
        {
            return;
        }

        var screen = PointToScreen(e.GetPosition(this));
        var dx = screen.X - _dragStartScreen.X;
        var dy = screen.Y - _dragStartScreen.Y;
        if (!_didDrag && Math.Abs(dx) + Math.Abs(dy) < 4)
        {
            return;
        }

        _didDrag = true;
        StopMovement();
        Left = _dragStartLeft + dx;
        Top = _dragStartTop + dy;
    }

    private void HandleLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_isDragging)
        {
            return;
        }

        _isDragging = false;
        ReleaseMouseCapture();

        if (_didDrag)
        {
            EnsureVisible();
            SaveSettings();
            if (_settings.IsVisible && !_settings.IsPaused && !_isPinnedForChat)
            {
                StartMovement();
            }
        }
        else
        {
            React();
        }
    }

    private void React()
    {
        if (_settings.IsPaused)
        {
            return;
        }

        _soundPlayer.Play(_settings.ClickSoundId, _settings.SoundVolumeId);
        _popUntil = DateTimeOffset.UtcNow.AddMilliseconds(180);
        Render();
    }

    private void TogglePause()
    {
        SetPaused(!_settings.IsPaused);
    }

    private void SetPaused(bool paused)
    {
        _settings.IsPaused = paused;
        if (paused)
        {
            StopMovement();
        }
        else
        {
            StartMovement();
            React();
        }

        SaveSettings();
        RefreshTrayMenu();
        Render();
    }

    private void TriggerAction(string action)
    {
        if (action == "chat")
        {
            ToggleChat();
            return;
        }

        React();
        new EffectsOverlayWindow(action, new WpfPoint(Left + Width / 2, Top + Height / 2), CurrentVisibleFrame()).Show();
    }

    private void ToggleChat()
    {
        if (_chatWindow is null)
        {
            OpenChat();
        }
        else
        {
            CloseChat();
        }
    }

    private void OpenChat()
    {
        _pauseStateBeforeChat ??= _settings.IsPaused;
        _isPinnedForChat = true;
        StopMovement();
        _chatWindow = new ChatWindow(_settings, _chatClient);
        _chatWindow.Closed += (_, _) =>
        {
            _chatWindow = null;
            if (_isDisposed)
            {
                return;
            }

            _isPinnedForChat = false;
            if (_pauseStateBeforeChat is { } wasPaused)
            {
                _pauseStateBeforeChat = null;
                SetPaused(wasPaused);
            }
            Render();
        };
        PositionChatWindow(_chatWindow);
        _chatWindow.Show();
        _chatWindow.Activate();
        Render();
    }

    private void CloseChat()
    {
        _chatWindow?.Close();
    }

    private void PositionChatWindow(Window chatWindow)
    {
        var frame = CurrentVisibleFrame();
        var gap = 12;
        var rightX = Left + Width + gap;
        var leftX = Left - chatWindow.Width - gap;
        chatWindow.Left = rightX + chatWindow.Width <= frame.MaxX ? rightX : Math.Max(frame.MinX + gap, leftX);
        var desiredY = Top + Height / 2 - chatWindow.Height * 0.58;
        chatWindow.Top = Math.Clamp(desiredY, frame.MinY + gap, frame.MaxY - chatWindow.Height - gap);
    }

    private void StartMovement()
    {
        if (!_settings.IsVisible || _settings.IsPaused || _isPinnedForChat || _movementTimer.IsEnabled || _restTimer is not null)
        {
            return;
        }

        ScheduleNextWander(TimeSpan.FromSeconds(0.4 + _random.NextDouble() * 0.8));
    }

    private void ScheduleNextWander(TimeSpan delay)
    {
        if (!_settings.IsVisible || _settings.IsPaused || _isPinnedForChat)
        {
            return;
        }

        _restTimer?.Stop();
        _restTimer = new DispatcherTimer { Interval = delay };
        _restTimer.Tick += (_, _) =>
        {
            _restTimer?.Stop();
            _restTimer = null;
            BeginWander();
        };
        _restTimer.Start();
    }

    private void BeginWander()
    {
        if (!_settings.IsVisible || _settings.IsPaused || _isPinnedForChat || _movementTimer.IsEnabled)
        {
            return;
        }

        _wanderMotion = _wanderPlanner.CreateMotion(
            new PointD(Left, Top),
            CurrentVisibleFrame(),
            new SizeD(Width, Height),
            _settings.SmartPositioningEnabled,
            DateTimeOffset.UtcNow);
        _movementTimer.Start();
    }

    private void TickMovement()
    {
        if (!_settings.IsVisible || _settings.IsPaused || _isPinnedForChat)
        {
            return;
        }

        if (_wanderMotion is null)
        {
            _movementTimer.Stop();
            ScheduleNextWander(TimeSpan.FromSeconds(6.5 + _random.NextDouble() * 4.5));
            return;
        }

        var now = DateTimeOffset.UtcNow;
        var progress = (now - _wanderMotion.StartedAt).TotalMilliseconds / Math.Max(1, _wanderMotion.Duration.TotalMilliseconds);
        var eased = progress * progress * (3 - 2 * progress);
        var point = _wanderMotion.PointAt(eased);
        Left = point.X;
        Top = point.Y;

        if (progress >= 1)
        {
            Left = _wanderMotion.End.X;
            Top = _wanderMotion.End.Y;
            _movementTimer.Stop();
            _wanderMotion = null;
            SaveSettings();
            _lastPositionSave = now;
            ScheduleNextWander(TimeSpan.FromSeconds(6.5 + _random.NextDouble() * 4.5));
        }

        if ((now - _lastPositionSave).TotalSeconds > 3)
        {
            SaveSettings();
            _lastPositionSave = now;
        }
    }

    private void StopMovement()
    {
        _movementTimer.Stop();
        _restTimer?.Stop();
        _restTimer = null;
        _wanderMotion = null;
    }

    private void ApplySavedOrDefaultPosition()
    {
        var frame = CurrentVisibleFrame();
        var origin = _settings.LastPosition is null
            ? ScreenClamp.DefaultOrigin(new SizeD(Width, Height), frame)
            : new PointD(_settings.LastPosition.X, _settings.LastPosition.Y);
        var clamped = ScreenClamp.ClampedOrigin(origin, new SizeD(Width, Height), frame);
        Left = clamped.X;
        Top = clamped.Y;
    }

    private void EnsureVisible()
    {
        var clamped = ScreenClamp.ClampedOrigin(new PointD(Left, Top), new SizeD(Width, Height), CurrentVisibleFrame());
        Left = clamped.X;
        Top = clamped.Y;
    }

    private RectD CurrentVisibleFrame()
    {
        var point = new Drawing.Point((int)(double.IsNaN(Left) ? 0 : Left + Width / 2), (int)(double.IsNaN(Top) ? 0 : Top + Height / 2));
        var screen = Forms.Screen.FromPoint(point).WorkingArea;
        return new RectD(screen.Left, screen.Top, screen.Width, screen.Height);
    }

    private void SaveSettings()
    {
        if (!double.IsNaN(Left) && !double.IsNaN(Top))
        {
            _settings.LastPosition = new SettingPoint(Left, Top);
        }

        _settingsStore.Save(_settings);
    }

    private void ResetPosition()
    {
        var origin = ScreenClamp.DefaultOrigin(new SizeD(Width, Height), CurrentVisibleFrame());
        Left = origin.X;
        Top = origin.Y;
        _settings.LastPosition = new SettingPoint(origin.X, origin.Y);
        ShowPet();
    }

    private ContextMenu BuildPetContextMenu()
    {
        var menu = new ContextMenu();
        AddMenuItem(menu.Items, _settings.IsVisible ? "Hide Bubbly" : "Show Bubbly", () => { if (_settings.IsVisible) HidePet(); else ShowPet(); });
        AddMenuItem(menu.Items, _settings.IsPaused ? "Resume" : "Pause", TogglePause);
        AddMenuItem(menu.Items, "Reset Position", ResetPosition);
        menu.Items.Add(new Separator());
        AddSubmenu(menu.Items, "Character", BubblyIds.Characters, id => ChangeSetting(s => s.CharacterId = id), _settings.CharacterId);
        AddSubmenu(menu.Items, "Theme", BubblyIds.Themes, id => ChangeSetting(s => s.ThemeId = id), _settings.ThemeId);
        AddSubmenu(menu.Items, "Mood", BubblyIds.Moods, id => ChangeSetting(s => s.MoodId = id), _settings.MoodId);
        AddSubmenu(menu.Items, "Feature Mode", BubblyIds.FeatureModes, id => ChangeSetting(s => s.FeatureModeId = id), _settings.FeatureModeId);
        AddSubmenu(menu.Items, "Click Sound", BubblyIds.ClickSounds, id => ChangeSetting(s => s.ClickSoundId = id), _settings.ClickSoundId);
        AddSubmenu(menu.Items, "Sound Volume", BubblyIds.SoundVolumes, id => ChangeSetting(s => s.SoundVolumeId = id), _settings.SoundVolumeId);
        AddCheckMenuItem(menu.Items, "Smart Positioning", _settings.SmartPositioningEnabled, () => ChangeSetting(s => s.SmartPositioningEnabled = !s.SmartPositioningEnabled));
        menu.Items.Add(new Separator());
        AddMenuItem(menu.Items, "Quit Bubbly", Quit);
        return menu;
    }

    private Forms.ContextMenuStrip BuildTrayMenu()
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Bubbly").Enabled = false;
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(_settings.IsVisible ? "Hide Bubbly" : "Show Bubbly", null, (_, _) => { if (_settings.IsVisible) HidePet(); else ShowPet(); });
        menu.Items.Add(_settings.IsPaused ? "Resume" : "Pause", null, (_, _) => TogglePause());
        menu.Items.Add("Reset Position", null, (_, _) => ResetPosition());
        AddTraySubmenu(menu, "Character", BubblyIds.Characters, id => ChangeSetting(s => s.CharacterId = id), _settings.CharacterId);
        AddTraySubmenu(menu, "Theme", BubblyIds.Themes, id => ChangeSetting(s => s.ThemeId = id), _settings.ThemeId);
        AddTraySubmenu(menu, "Mood", BubblyIds.Moods, id => ChangeSetting(s => s.MoodId = id), _settings.MoodId);
        AddTraySubmenu(menu, "Feature Mode", BubblyIds.FeatureModes, id => ChangeSetting(s => s.FeatureModeId = id), _settings.FeatureModeId);
        AddTraySubmenu(menu, "Click Sound", BubblyIds.ClickSounds, id => ChangeSetting(s => s.ClickSoundId = id), _settings.ClickSoundId);
        AddTraySubmenu(menu, "Sound Volume", BubblyIds.SoundVolumes, id => ChangeSetting(s => s.SoundVolumeId = id), _settings.SoundVolumeId);
        var smart = new Forms.ToolStripMenuItem("Smart Positioning") { Checked = _settings.SmartPositioningEnabled };
        smart.Click += (_, _) => ChangeSetting(s => s.SmartPositioningEnabled = !s.SmartPositioningEnabled);
        menu.Items.Add(smart);
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Quit Bubbly", null, (_, _) => Quit());
        return menu;
    }

    private void RefreshTrayMenu()
    {
        if (_isDisposed)
        {
            return;
        }

        _notifyIcon.ContextMenuStrip?.Dispose();
        _notifyIcon.ContextMenuStrip = BuildTrayMenu();
    }

    private static void AddMenuItem(ItemCollection items, string title, Action action)
    {
        var item = new System.Windows.Controls.MenuItem { Header = title };
        item.Click += (_, _) => action();
        items.Add(item);
    }

    private static void AddCheckMenuItem(ItemCollection items, string title, bool isChecked, Action action)
    {
        var item = new System.Windows.Controls.MenuItem { Header = title, IsCheckable = true, IsChecked = isChecked };
        item.Click += (_, _) => action();
        items.Add(item);
    }

    private static void AddSubmenu(ItemCollection items, string title, IEnumerable<string> ids, Action<string> choose, string selected)
    {
        var parent = new System.Windows.Controls.MenuItem { Header = title };
        foreach (var id in ids)
        {
            var item = new System.Windows.Controls.MenuItem
            {
                Header = BubblyIds.TitleFor(id),
                IsCheckable = true,
                IsChecked = id == selected
            };
            item.Click += (_, _) => choose(id);
            parent.Items.Add(item);
        }
        items.Add(parent);
    }

    private static void AddTraySubmenu(Forms.ContextMenuStrip menu, string title, IEnumerable<string> ids, Action<string> choose, string selected)
    {
        var parent = new Forms.ToolStripMenuItem(title);
        foreach (var id in ids)
        {
            var item = new Forms.ToolStripMenuItem(BubblyIds.TitleFor(id)) { Checked = id == selected };
            item.Click += (_, _) => choose(id);
            parent.DropDownItems.Add(item);
        }
        menu.Items.Add(parent);
    }

    private void ChangeSetting(Action<BubblySettings> apply)
    {
        apply(_settings);
        _settings.Normalize();
        if (!BubblyIds.EnabledActions(_settings.FeatureModeId).Contains("chat"))
        {
            CloseChat();
        }
        SaveSettings();
        RefreshTrayMenu();
        Render();
    }

    private void Quit()
    {
        SaveSettings();
        Dispose();
        Application.Current.Shutdown();
    }

    private static Drawing.Icon CreateTrayIcon()
    {
        using var bitmap = new Drawing.Bitmap(32, 32);
        using var graphics = Drawing.Graphics.FromImage(bitmap);
        graphics.SmoothingMode = Drawing.Drawing2D.SmoothingMode.AntiAlias;
        using var fill = new Drawing.Drawing2D.LinearGradientBrush(
            new Drawing.Rectangle(0, 0, 32, 32),
            Drawing.Color.FromArgb(172, 226, 252),
            Drawing.Color.FromArgb(70, 132, 222),
            45);
        graphics.FillEllipse(fill, 3, 3, 26, 26);
        using var shine = new Drawing.SolidBrush(Drawing.Color.FromArgb(150, Drawing.Color.White));
        graphics.FillEllipse(shine, 9, 7, 8, 6);
        using var pen = new Drawing.Pen(Drawing.Color.White, 2);
        graphics.DrawEllipse(pen, 3, 3, 26, 26);
        return Drawing.Icon.FromHandle(bitmap.GetHicon());
    }

    private string ClientVersion()
    {
        return Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "0.1.0";
    }

    private sealed record ThemeProfile(MediaColor Highlight, MediaColor Mid, MediaColor Deep)
    {
        public static ThemeProfile For(string id) => id switch
        {
            "strawberry" => new(Color.FromRgb(255, 245, 250), Color.FromRgb(255, 130, 168), Color.FromRgb(227, 64, 107)),
            "mint" => new(Color.FromRgb(240, 255, 247), Color.FromRgb(115, 224, 184), Color.FromRgb(51, 163, 140)),
            "sunset" => new(Color.FromRgb(255, 247, 224), Color.FromRgb(255, 156, 97), Color.FromRgb(224, 89, 102)),
            "lavender" => new(Color.FromRgb(250, 245, 255), Color.FromRgb(168, 148, 240), Color.FromRgb(115, 99, 199)),
            _ => new(Color.FromRgb(240, 250, 255), Color.FromRgb(112, 201, 242), Color.FromRgb(79, 145, 224))
        };
    }

    private sealed record MoodProfile(double BreathRate, double BreathAmount, double BobRate, double BobAmount, double SmileDepth, double SmileOffsetX)
    {
        public static MoodProfile For(string id) => id switch
        {
            "sleepy" => new(1.1, 0.018, 1.0, 2, 6, 0),
            "shy" => new(1.7, 0.014, 1.5, 2.5, 10, -4),
            "focus" => new(0.9, 0.008, 0.7, 1, 5, 0),
            _ => new(2.0, 0.025, 2.4, 4, 16, 0)
        };

        public double EyeHeight(DateTimeOffset now)
        {
            var t = now.ToUnixTimeMilliseconds() / 1000.0;
            return SmileDepth switch
            {
                6 => 4,
                10 => t % 5.5 > 5.2 ? 3 : 15,
                5 => 12,
                _ => t % 4.7 > 4.48 ? 3 : 19
            };
        }
    }
}
