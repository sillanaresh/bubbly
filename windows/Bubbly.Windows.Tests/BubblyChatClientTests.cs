using System.Net;
using System.Net.Http;
using Bubbly.Windows.Services;
using Xunit;

namespace Bubbly.Windows.Tests;

public sealed class BubblyChatClientTests
{
    [Fact]
    public void BuildRequestJsonUsesExpectedWireShape()
    {
        var json = BubblyChatClient.BuildRequestJson(
            "device-1",
            [new ChatMessage("user", "hello")],
            "0.1.0");

        Assert.Contains("\"deviceId\":\"device-1\"", json);
        Assert.Contains("\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]", json);
        Assert.Contains("\"clientVersion\":\"0.1.0\"", json);
    }

    [Fact]
    public async Task SendAsyncParsesSuccessfulResponse()
    {
        var handler = new StubHandler(new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("{\"message\":\"Hi there\",\"model\":\"hidden\",\"remainingToday\":29}")
        });
        var client = new BubblyChatClient(new HttpClient(handler), new Uri("https://example.test/chat"));

        var result = await client.SendAsync("device-1", [new ChatMessage("user", "hi")], "0.1.0");

        Assert.Equal("Hi there", result.Message);
        Assert.Equal(29, result.RemainingToday);
    }

    [Fact]
    public async Task SendAsyncThrowsFriendlyBackendError()
    {
        var handler = new StubHandler(new HttpResponseMessage(HttpStatusCode.TooManyRequests)
        {
            Content = new StringContent("{\"error\":\"Bubbly Free chat is busy for today.\",\"code\":\"daily_limit\"}")
        });
        var client = new BubblyChatClient(new HttpClient(handler), new Uri("https://example.test/chat"));

        var error = await Assert.ThrowsAsync<ChatException>(() =>
            client.SendAsync("device-1", [new ChatMessage("user", "hi")], "0.1.0"));

        Assert.Equal("Bubbly Free chat is busy for today.", error.Message);
    }

    private sealed class StubHandler(HttpResponseMessage response) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Assert.Equal(HttpMethod.Post, request.Method);
            Assert.Equal("https://example.test/chat", request.RequestUri?.AbsoluteUri);
            return Task.FromResult(response);
        }
    }
}
