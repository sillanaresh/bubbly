# Habibi Float Backend

Small Cloudflare Worker backend for the Bubbly Free AI chat mode.

The macOS app calls this backend. The backend owns the OpenRouter API key, enforces daily limits, and forwards approved chat requests to OpenRouter.

## Why This Exists

Do not put the OpenRouter key in the macOS app. A distributed desktop app can be inspected, so any embedded key can eventually be extracted. Keep the key in Cloudflare as a secret instead.

## Local Setup

```sh
cd backend
npm install
npm test
npm run typecheck
```

For local Worker testing, create `backend/.dev.vars`:

```sh
OPENROUTER_API_KEY=your_openrouter_key_here
```

Do not commit `.dev.vars`.

## Cloudflare Setup

1. Log in:

```sh
npx wrangler login
```

2. Create the KV namespace for daily usage counters:

```sh
npx wrangler kv namespace create HABIBI_USAGE
```

3. Copy the returned `id` into `wrangler.toml`.

4. Add the OpenRouter key as a secret:

```sh
npx wrangler secret put OPENROUTER_API_KEY
```

5. Deploy:

```sh
npm run deploy
```

## API

### `GET /health`

Returns backend status.

### `POST /v1/chat`

Request:

```json
{
  "deviceId": "anonymous-device-id",
  "clientVersion": "0.1.0",
  "messages": [
    { "role": "user", "content": "hello" }
  ]
}
```

Response:

```json
{
  "message": "Hi!",
  "model": "openrouter/free",
  "remainingToday": 29
}
```

Error:

```json
{
  "error": "Daily chat limit reached for today.",
  "code": "daily_limit_reached"
}
```

## Limits

Defaults are configured in `wrangler.toml`:

- `30` Bubbly Free messages per device per day
- `1000` Bubbly Free messages globally per day
- `8000` input characters per request
- `350` max output tokens

The default model is `openrouter/free`, which routes to currently available free OpenRouter models. OpenRouter free model availability and limits can change, so we should revisit the model choice before a wider release.

Daily counters use Cloudflare KV. This is good enough for early friend-sharing usage. For a large public release, replace KV counters with Durable Objects or another strongly consistent store so simultaneous requests cannot briefly exceed the exact daily limit.
