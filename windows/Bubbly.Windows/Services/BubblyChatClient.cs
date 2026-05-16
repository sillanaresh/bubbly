using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace Bubbly.Windows.Services;

public sealed class BubblyChatClient
{
    public static readonly Uri DefaultEndpoint = new("https://habibi-float-api.habibi-float.workers.dev/v1/chat");

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private readonly HttpClient _httpClient;
    private readonly Uri _endpoint;

    public BubblyChatClient(HttpClient httpClient, Uri? endpoint = null)
    {
        _httpClient = httpClient;
        _endpoint = endpoint ?? DefaultEndpoint;
    }

    public static string BuildRequestJson(string deviceId, IReadOnlyList<ChatMessage> messages, string clientVersion)
    {
        return JsonSerializer.Serialize(new ChatRequest(deviceId, messages, clientVersion), JsonOptions);
    }

    public async Task<ChatResult> SendAsync(string deviceId, IReadOnlyList<ChatMessage> messages, string clientVersion, CancellationToken cancellationToken = default)
    {
        var json = BuildRequestJson(deviceId, messages, clientVersion);
        using var request = new HttpRequestMessage(HttpMethod.Post, _endpoint)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };
        request.Headers.Accept.ParseAdd("application/json");

        HttpResponseMessage response;
        try
        {
            response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            throw new ChatException("Bubbly Free chat is offline right now.");
        }

        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        if (response.StatusCode is < HttpStatusCode.OK or >= HttpStatusCode.MultipleChoices)
        {
            var message = TryReadError(body) ?? "Bubbly Free chat is having trouble right now.";
            throw new ChatException(message);
        }

        try
        {
            var chatResponse = JsonSerializer.Deserialize<ChatResponse>(body, JsonOptions);
            var cleaned = CleanAssistantMessage(chatResponse?.Message);
            if (string.IsNullOrWhiteSpace(cleaned))
            {
                throw new ChatException("Bubbly sent an empty reply.");
            }

            return new ChatResult(cleaned, chatResponse?.RemainingToday);
        }
        catch (ChatException)
        {
            throw;
        }
        catch
        {
            throw new ChatException("Bubbly Free chat returned something unexpected.");
        }
    }

    private static string? TryReadError(string body)
    {
        try
        {
            return JsonSerializer.Deserialize<ChatError>(body, JsonOptions)?.Error;
        }
        catch
        {
            return null;
        }
    }

    private static string? CleanAssistantMessage(string? content)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            return null;
        }

        var text = content.Trim();
        while (true)
        {
            var start = text.IndexOf("<think>", StringComparison.OrdinalIgnoreCase);
            var end = text.IndexOf("</think>", StringComparison.OrdinalIgnoreCase);
            if (start < 0 || end < 0 || start >= end)
            {
                break;
            }

            text = text.Remove(start, end + "</think>".Length - start);
        }

        return text
            .Replace("<think>", string.Empty, StringComparison.OrdinalIgnoreCase)
            .Replace("</think>", string.Empty, StringComparison.OrdinalIgnoreCase)
            .Trim();
    }
}

public sealed record ChatMessage(string Role, string Content);
public sealed record ChatResult(string Message, int? RemainingToday);
public sealed class ChatException(string message) : Exception(message);

file sealed record ChatRequest(string DeviceId, IReadOnlyList<ChatMessage> Messages, string ClientVersion);
file sealed record ChatResponse(string Message, string? Model, int? RemainingToday);
file sealed record ChatError(string Error, string? Code);
