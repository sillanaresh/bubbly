using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Bubbly.Windows.Models;
using Bubbly.Windows.Services;
using WpfButton = System.Windows.Controls.Button;
using WpfTextBox = System.Windows.Controls.TextBox;

namespace Bubbly.Windows.Views;

public sealed class ChatWindow : Window
{
    private readonly BubblySettings _settings;
    private readonly BubblyChatClient _chatClient;
    private readonly List<ChatMessage> _messages = [];
    private readonly StackPanel _history = new();
    private readonly ScrollViewer _scrollViewer;
    private readonly WpfTextBox _input = new();
    private readonly TextBlock _status = new();
    private readonly WpfButton _sendButton = new();
    private bool _isSending;

    public ChatWindow(BubblySettings settings, BubblyChatClient chatClient)
    {
        _settings = settings;
        _chatClient = chatClient;

        Title = "Bubbly Chat";
        Icon = new BitmapImage(new Uri("pack://application:,,,/Assets/bubbly-app-icon.png"));
        Width = 380;
        Height = 460;
        MinWidth = 320;
        MinHeight = 360;
        MaxWidth = 560;
        MaxHeight = 720;
        Topmost = true;
        WindowStartupLocation = WindowStartupLocation.Manual;

        var root = new DockPanel { Background = SystemColors.WindowBrush };
        Content = root;

        var header = BuildHeader();
        DockPanel.SetDock(header, Dock.Top);
        root.Children.Add(header);

        var composer = BuildComposer();
        DockPanel.SetDock(composer, Dock.Bottom);
        root.Children.Add(composer);

        _scrollViewer = new ScrollViewer
        {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Content = _history
        };
        root.Children.Add(_scrollViewer);
        RenderHistory();
    }

    private UIElement BuildHeader()
    {
        var panel = new DockPanel { LastChildFill = true, Margin = new Thickness(14, 14, 14, 10) };
        var close = new WpfButton
        {
            Content = "X",
            Width = 28,
            Height = 28,
            ToolTip = "Close chat"
        };
        close.Click += (_, _) => Close();
        DockPanel.SetDock(close, Dock.Right);
        panel.Children.Add(close);

        var text = new StackPanel();
        text.Children.Add(new TextBlock
        {
            Text = "Bubbly Free",
            FontSize = 13,
            FontWeight = FontWeights.SemiBold
        });
        _status.Text = "50 free messages";
        _status.FontSize = 11;
        _status.Foreground = Brushes.Gray;
        text.Children.Add(_status);
        panel.Children.Add(text);
        return new Border { Child = panel, BorderBrush = Brushes.Gainsboro, BorderThickness = new Thickness(0, 0, 0, 1) };
    }

    private UIElement BuildComposer()
    {
        var panel = new DockPanel { Margin = new Thickness(14), LastChildFill = true };
        var clear = new WpfButton { Content = "Clear", MinWidth = 54, Margin = new Thickness(8, 0, 0, 0), ToolTip = "Clear history" };
        clear.Click += (_, _) =>
        {
            _messages.Clear();
            RenderHistory();
        };
        DockPanel.SetDock(clear, Dock.Right);
        panel.Children.Add(clear);

        _sendButton.Content = "Send";
        _sendButton.MinWidth = 54;
        _sendButton.Margin = new Thickness(8, 0, 0, 0);
        _sendButton.Click += async (_, _) => await SendAsync();
        DockPanel.SetDock(_sendButton, Dock.Right);
        panel.Children.Add(_sendButton);

        _input.MinHeight = 30;
        _input.VerticalContentAlignment = VerticalAlignment.Center;
        _input.KeyDown += async (_, args) =>
        {
            if (args.Key == Key.Enter && Keyboard.Modifiers == ModifierKeys.None)
            {
                args.Handled = true;
                await SendAsync();
            }
        };
        panel.Children.Add(_input);
        return new Border { Child = panel, BorderBrush = Brushes.Gainsboro, BorderThickness = new Thickness(0, 1, 0, 0) };
    }

    private async Task SendAsync()
    {
        var text = _input.Text.Trim();
        if (_isSending || string.IsNullOrWhiteSpace(text))
        {
            return;
        }

        _isSending = true;
        _sendButton.IsEnabled = false;
        _input.Clear();
        _status.Text = "Bubbly is typing";
        _messages.Add(new ChatMessage("user", text));
        RenderHistory(showTyping: true);

        try
        {
            var result = await _chatClient.SendAsync(_settings.DeviceId, _messages, "0.1.0");
            _messages.Add(new ChatMessage("assistant", result.Message));
            _status.Text = result.RemainingToday.HasValue ? $"Bubbly Free, {result.RemainingToday.Value} left" : "Bubbly Free";
        }
        catch (ChatException ex)
        {
            _status.Text = ex.Message;
        }
        finally
        {
            _isSending = false;
            _sendButton.IsEnabled = true;
            RenderHistory();
        }
    }

    private void RenderHistory(bool showTyping = false)
    {
        _history.Children.Clear();
        _history.Margin = new Thickness(0, 12, 0, 12);

        if (_messages.Count == 0)
        {
            _history.Children.Add(new TextBlock
            {
                Text = "Ask Bubbly something",
                Foreground = Brushes.Gray,
                FontWeight = FontWeights.Medium,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 84, 0, 0)
            });
        }

        foreach (var message in _messages)
        {
            _history.Children.Add(MessageBubble(message));
        }

        if (showTyping)
        {
            _history.Children.Add(new TextBlock
            {
                Text = "Bubbly is typing",
                Foreground = Brushes.Gray,
                Margin = new Thickness(14, 4, 14, 4)
            });
        }

        _ = Dispatcher.InvokeAsync(() => _scrollViewer.ScrollToEnd());
    }

    private static UIElement MessageBubble(ChatMessage message)
    {
        var isUser = message.Role == "user";
        var bubble = new Border
        {
            Background = isUser ? new SolidColorBrush(Color.FromRgb(72, 130, 210)) : new SolidColorBrush(Color.FromRgb(224, 243, 253)),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(12, 9, 12, 9),
            MaxWidth = 300,
            Child = new TextBlock
            {
                Text = message.Content,
                TextWrapping = TextWrapping.Wrap,
                Foreground = isUser ? Brushes.White : new SolidColorBrush(Color.FromRgb(23, 51, 79))
            }
        };
        return new DockPanel
        {
            LastChildFill = false,
            Margin = new Thickness(14, 4, 14, 6),
            Children =
            {
                new Border
                {
                    Child = bubble,
                    HorizontalAlignment = isUser ? HorizontalAlignment.Right : HorizontalAlignment.Left
                }
            }
        };
    }
}
