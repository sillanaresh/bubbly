export interface Env {
  HABIBI_USAGE: KVNamespace;
  OPENROUTER_API_KEY: string;
  OPENROUTER_MODEL?: string;
  DAILY_DEVICE_LIMIT?: string;
  GLOBAL_DAILY_LIMIT?: string;
  MAX_INPUT_CHARS?: string;
  MAX_OUTPUT_TOKENS?: string;
  KILL_SWITCH?: string;
  ALLOWED_ORIGIN?: string;
  APP_REFERER?: string;
  APP_TITLE?: string;
}

type ChatRole = "system" | "user" | "assistant";

interface ChatMessage {
  role: ChatRole;
  content: string;
}

interface ChatRequest {
  deviceId: string;
  clientVersion?: string;
  messages: ChatMessage[];
}

interface OpenRouterResponse {
  model?: string;
  choices?: Array<{
    message?: {
      content?: string;
    };
  }>;
  error?: {
    message?: string;
    code?: string | number;
  };
}

interface QuotaReservation {
  remaining: number;
  release: () => Promise<void>;
}

const OPENROUTER_CHAT_URL = "https://openrouter.ai/api/v1/chat/completions";
const DEFAULT_MODEL = "openrouter/free";
const DEFAULT_DAILY_DEVICE_LIMIT = 50;
const DEFAULT_GLOBAL_DAILY_LIMIT = 1000;
const DEFAULT_MAX_INPUT_CHARS = 8000;
const DEFAULT_MAX_OUTPUT_TOKENS = 350;
const MAX_MESSAGES = 20;
const DEVICE_ID_PATTERN = /^[A-Za-z0-9._:-]{8,128}$/;
const SYSTEM_PROMPT = [
  "You are Bubbly, the cute floating bubble companion inside Habibi Float, a macOS desktop pet app.",
  "Be warm, concise, and playful without being childish.",
  "If asked who you are, say you are Bubbly from Habibi Float.",
  "Do not claim to be the underlying model or provider.",
  "Avoid abusive, hateful, sexual, or dangerous content; if a request is unsafe, gently refuse and offer a harmless alternative."
].join(" ");

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return handleRequest(request, env);
  }
};

export async function handleRequest(request: Request, env: Env): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(request, env) });
  }

  const url = new URL(request.url);

  if (request.method === "GET" && url.pathname === "/health") {
    return jsonResponse(request, env, 200, {
      status: "ok",
      service: "habibi-float-api"
    });
  }

  if (request.method === "POST" && url.pathname === "/v1/chat") {
    return handleChat(request, env);
  }

  return jsonResponse(request, env, 404, {
    error: "Not found.",
    code: "not_found"
  });
}

async function handleChat(request: Request, env: Env): Promise<Response> {
  if (env.KILL_SWITCH === "1" || env.KILL_SWITCH?.toLowerCase() === "true") {
    return jsonResponse(request, env, 503, {
      error: "Bubbly Free chat is temporarily unavailable.",
      code: "service_disabled"
    });
  }

  if (!env.OPENROUTER_API_KEY) {
    return jsonResponse(request, env, 500, {
      error: "Chat is not configured yet.",
      code: "missing_openrouter_key"
    });
  }

  const parsed = await parseChatRequest(request, env);
  if (!parsed.ok) {
    return jsonResponse(request, env, parsed.status, {
      error: parsed.error,
      code: parsed.code
    });
  }

  const day = utcDay();
  const deviceLimit = readPositiveInt(env.DAILY_DEVICE_LIMIT, DEFAULT_DAILY_DEVICE_LIMIT);
  const globalLimit = readPositiveInt(env.GLOBAL_DAILY_LIMIT, DEFAULT_GLOBAL_DAILY_LIMIT);

  let globalReservation: QuotaReservation | undefined;
  let deviceReservation: QuotaReservation | undefined;

  try {
    globalReservation = await reserveQuota(env.HABIBI_USAGE, "global", day, globalLimit);
    if (!globalReservation) {
      return jsonResponse(request, env, 429, {
        error: "Bubbly Free chat is busy for today. Try again tomorrow or use your own OpenRouter key.",
        code: "global_limit_reached"
      });
    }

    deviceReservation = await reserveQuota(env.HABIBI_USAGE, `device:${parsed.value.deviceId}`, day, deviceLimit);
    if (!deviceReservation) {
      await globalReservation.release();
      return jsonResponse(request, env, 429, {
        error: "Daily chat limit reached for today.",
        code: "daily_limit_reached"
      });
    }

    const completion = await requestOpenRouter(parsed.value.messages, env);

    return jsonResponse(request, env, 200, {
      message: completion.message,
      model: completion.model,
      remainingToday: deviceReservation.remaining
    });
  } catch (error) {
    await refundQuietly(deviceReservation);
    await refundQuietly(globalReservation);

    const message = error instanceof Error ? error.message : "Unable to reach the chat service.";
    return jsonResponse(request, env, 502, {
      error: message,
      code: "upstream_error"
    });
  }
}

type ParseResult =
  | { ok: true; value: ChatRequest }
  | { ok: false; status: number; error: string; code: string };

async function parseChatRequest(request: Request, env: Env): Promise<ParseResult> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return {
      ok: false,
      status: 415,
      error: "Request must be JSON.",
      code: "invalid_content_type"
    };
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return {
      ok: false,
      status: 400,
      error: "Request JSON is invalid.",
      code: "invalid_json"
    };
  }

  if (!isRecord(body)) {
    return invalidRequest("Request body is invalid.");
  }

  const deviceId = body.deviceId;
  if (typeof deviceId !== "string" || !DEVICE_ID_PATTERN.test(deviceId)) {
    return invalidRequest("Device id is invalid.");
  }

  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > MAX_MESSAGES) {
    return invalidRequest(`Messages must include 1 to ${MAX_MESSAGES} items.`);
  }

  const sanitized: ChatMessage[] = [];
  let totalChars = 0;

  for (const item of messages) {
    if (!isRecord(item)) {
      return invalidRequest("Each message must be an object.");
    }

    const role = item.role;
    const content = item.content;

    if (role !== "system" && role !== "user" && role !== "assistant") {
      return invalidRequest("Message role is invalid.");
    }

    if (typeof content !== "string" || content.trim().length === 0) {
      return invalidRequest("Message content is required.");
    }

    const trimmed = content.trim();
    totalChars += trimmed.length;
    sanitized.push({ role, content: trimmed });
  }

  const maxInputChars = readPositiveInt(env.MAX_INPUT_CHARS, DEFAULT_MAX_INPUT_CHARS);
  if (totalChars > maxInputChars) {
    return {
      ok: false,
      status: 413,
      error: "Message is too long.",
      code: "input_too_large"
    };
  }

  const clientVersion = typeof body.clientVersion === "string" ? body.clientVersion.slice(0, 40) : undefined;

  return {
    ok: true,
    value: {
      deviceId,
      ...(clientVersion ? { clientVersion } : {}),
      messages: sanitized
    }
  };
}

function invalidRequest(error: string): ParseResult {
  return {
    ok: false,
    status: 400,
    error,
    code: "invalid_request"
  };
}

async function requestOpenRouter(messages: ChatMessage[], env: Env): Promise<{ message: string; model: string }> {
  const model = env.OPENROUTER_MODEL || DEFAULT_MODEL;
  const maxTokens = readPositiveInt(env.MAX_OUTPUT_TOKENS, DEFAULT_MAX_OUTPUT_TOKENS);

  const response = await fetch(OPENROUTER_CHAT_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
      "HTTP-Referer": env.APP_REFERER || "https://habibi-float.local",
      "X-Title": env.APP_TITLE || "Habibi Float"
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        ...messages.filter((message) => message.role !== "system")
      ],
      max_tokens: maxTokens,
      temperature: 0.8
    })
  });

  const data = await response.json().catch(() => undefined) as OpenRouterResponse | undefined;

  if (!response.ok) {
    const upstreamMessage = data?.error?.message;
    throw new Error(upstreamMessage || "OpenRouter request failed.");
  }

  const content = cleanAssistantMessage(data?.choices?.[0]?.message?.content);
  if (!content) {
    throw new Error("Bubbly had trouble answering. Please try again.");
  }

  return {
    message: content,
    model: data?.model || model
  };
}

function cleanAssistantMessage(content: string | undefined): string | undefined {
  if (!content) {
    return undefined;
  }

  let text = content.trim();
  if (!text) {
    return undefined;
  }

  text = text.replace(/<think>[\s\S]*?<\/think>/gi, "");
  text = text.replace(/<\/?think>/gi, "");

  const cleaned = text
    .split("\n")
    .filter((line) => !line.trim().toLowerCase().startsWith("thinking about how to respond"))
    .join("\n")
    .trim();

  return cleaned || undefined;
}

async function reserveQuota(
  usage: KVNamespace,
  scope: string,
  day: string,
  limit: number
): Promise<QuotaReservation | undefined> {
  const key = usageKey(scope, day);
  const current = await usage.get(key, "json") as number | null;
  const count = typeof current === "number" && Number.isFinite(current) ? current : 0;

  if (count >= limit) {
    return undefined;
  }

  const next = count + 1;
  await usage.put(key, JSON.stringify(next), { expirationTtl: secondsUntilTomorrowUtc() + 3600 });

  return {
    remaining: Math.max(0, limit - next),
    release: () => refundQuota(usage, scope, day)
  };
}

async function refundQuota(usage: KVNamespace, scope: string, day: string): Promise<void> {
  const key = usageKey(scope, day);
  const current = await usage.get(key, "json") as number | null;
  const count = typeof current === "number" && Number.isFinite(current) ? current : 0;

  await usage.put(key, JSON.stringify(Math.max(0, count - 1)), {
    expirationTtl: secondsUntilTomorrowUtc() + 3600
  });
}

async function refundQuietly(reservation: QuotaReservation | undefined): Promise<void> {
  if (!reservation) {
    return;
  }

  try {
    await reservation.release();
  } catch {
    // Do not mask the user-facing upstream error with quota refund failure.
  }
}

function readPositiveInt(value: string | undefined, fallback: number): number {
  if (!value) {
    return fallback;
  }

  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function utcDay(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

function usageKey(scope: string, day: string): string {
  return `usage:${day}:${scope}`;
}

function secondsUntilTomorrowUtc(now = new Date()): number {
  const tomorrow = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() + 1,
    0,
    0,
    0,
    0
  ));

  return Math.max(60, Math.ceil((tomorrow.getTime() - now.getTime()) / 1000));
}

function jsonResponse(request: Request, env: Env, status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders(request, env)
    }
  });
}

function corsHeaders(request: Request, env: Env): HeadersInit {
  const origin = request.headers.get("origin");
  const allowedOrigin = env.ALLOWED_ORIGIN;

  if (!origin || !allowedOrigin) {
    return {
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type"
    };
  }

  if (allowedOrigin === "*" || allowedOrigin === origin) {
    return {
      "Access-Control-Allow-Origin": origin,
      "Vary": "Origin",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type"
    };
  }

  return {
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export const testing = {
  parseChatRequest,
  reserveQuota,
  readPositiveInt,
  cleanAssistantMessage
};
