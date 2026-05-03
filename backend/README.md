# Habibi Float Backend

Small Cloudflare Worker backend for the sponsored AI chat mode.

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

2. Create the D1 database:

```sh
npx wrangler d1 create habibi-float-api-db
```

3. Copy the returned `database_id` into `wrangler.toml`.

4. Create the table:

```sh
npm run db:migrate:remote
```

5. Add the OpenRouter key as a secret:

```sh
npx wrangler secret put OPENROUTER_API_KEY
```

6. Deploy:

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

- `30` sponsored messages per device per day
- `1000` sponsored messages globally per day
- `8000` input characters per request
- `350` max output tokens

The default model is `openrouter/free`, which routes to currently available free OpenRouter models. OpenRouter free model availability and limits can change, so we should revisit the model choice before a wider release.

