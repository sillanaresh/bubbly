import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { handleRequest, type Env } from "../src/index";

class InMemoryD1 {
  private readonly counts = new Map<string, number>();

  prepare(sql: string) {
    return {
      bind: (...args: unknown[]) => ({
        first: async <T>() => {
          if (!sql.includes("INSERT INTO daily_usage")) {
            return null;
          }

          const scope = String(args[0]);
          const day = String(args[1]);
          const limit = Number(args[2]);
          const key = `${scope}|${day}`;
          const current = this.counts.get(key) ?? 0;

          if (current >= limit) {
            return null;
          }

          const next = current + 1;
          this.counts.set(key, next);
          return { count: next } as T;
        },
        run: async () => {
          if (!sql.includes("UPDATE daily_usage")) {
            return { success: true };
          }

          const scope = String(args[0]);
          const day = String(args[1]);
          const key = `${scope}|${day}`;
          const current = this.counts.get(key) ?? 0;
          this.counts.set(key, Math.max(0, current - 1));
          return { success: true };
        }
      })
    };
  }
}

function env(overrides: Partial<Env> = {}): Env {
  return {
    HABIBI_DB: new InMemoryD1() as unknown as D1Database,
    OPENROUTER_API_KEY: "test-key",
    OPENROUTER_MODEL: "openrouter/free",
    DAILY_DEVICE_LIMIT: "30",
    GLOBAL_DAILY_LIMIT: "1000",
    MAX_INPUT_CHARS: "8000",
    MAX_OUTPUT_TOKENS: "350",
    ...overrides
  };
}

function chatRequest(body: unknown): Request {
  return new Request("https://habibi.test/v1/chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });
}

async function readJson(response: Response): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

describe("Habibi Float backend", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn(async () => new Response(JSON.stringify({
      model: "upstream/free-model",
      choices: [
        {
          message: {
            content: "Hello from Habibi."
          }
        }
      ]
    }), {
      status: 200,
      headers: {
        "Content-Type": "application/json"
      }
    })));
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("returns health status", async () => {
    const response = await handleRequest(new Request("https://habibi.test/health"), env());
    const json = await readJson(response);

    expect(response.status).toBe(200);
    expect(json.status).toBe("ok");
  });

  it("rejects non-json chat requests", async () => {
    const response = await handleRequest(new Request("https://habibi.test/v1/chat", {
      method: "POST",
      body: "hello"
    }), env());
    const json = await readJson(response);

    expect(response.status).toBe(415);
    expect(json.code).toBe("invalid_content_type");
  });

  it("proxies a valid chat request to OpenRouter", async () => {
    const response = await handleRequest(chatRequest({
      deviceId: "device-12345",
      clientVersion: "0.1.0",
      messages: [
        { role: "user", content: "hello" }
      ]
    }), env());

    const json = await readJson(response);

    expect(response.status).toBe(200);
    expect(json.message).toBe("Hello from Habibi.");
    expect(json.model).toBe("upstream/free-model");
    expect(json.remainingToday).toBe(29);
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it("enforces per-device daily limits", async () => {
    const sharedEnv = env({ DAILY_DEVICE_LIMIT: "1" });

    const first = await handleRequest(chatRequest({
      deviceId: "device-limit",
      messages: [
        { role: "user", content: "first" }
      ]
    }), sharedEnv);

    const second = await handleRequest(chatRequest({
      deviceId: "device-limit",
      messages: [
        { role: "user", content: "second" }
      ]
    }), sharedEnv);

    const secondJson = await readJson(second);

    expect(first.status).toBe(200);
    expect(second.status).toBe(429);
    expect(secondJson.code).toBe("daily_limit_reached");
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it("refunds quota when OpenRouter fails", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({
        error: {
          message: "temporary upstream failure"
        }
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json"
        }
      }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        model: "upstream/free-model",
        choices: [
          {
            message: {
              content: "Recovered."
            }
          }
        ]
      }), {
        status: 200,
        headers: {
          "Content-Type": "application/json"
        }
      }));

    vi.stubGlobal("fetch", fetchMock);

    const sharedEnv = env({ DAILY_DEVICE_LIMIT: "1" });

    const failed = await handleRequest(chatRequest({
      deviceId: "device-refund",
      messages: [
        { role: "user", content: "first" }
      ]
    }), sharedEnv);

    const recovered = await handleRequest(chatRequest({
      deviceId: "device-refund",
      messages: [
        { role: "user", content: "second" }
      ]
    }), sharedEnv);

    const recoveredJson = await readJson(recovered);

    expect(failed.status).toBe(502);
    expect(recovered.status).toBe(200);
    expect(recoveredJson.message).toBe("Recovered.");
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it("does not call OpenRouter when the global daily limit is reached", async () => {
    const sharedEnv = env({ GLOBAL_DAILY_LIMIT: "1" });

    const first = await handleRequest(chatRequest({
      deviceId: "device-a",
      messages: [
        { role: "user", content: "first" }
      ]
    }), sharedEnv);

    const second = await handleRequest(chatRequest({
      deviceId: "device-b",
      messages: [
        { role: "user", content: "second" }
      ]
    }), sharedEnv);

    const secondJson = await readJson(second);

    expect(first.status).toBe(200);
    expect(second.status).toBe(429);
    expect(secondJson.code).toBe("global_limit_reached");
    expect(fetch).toHaveBeenCalledTimes(1);
  });
});

