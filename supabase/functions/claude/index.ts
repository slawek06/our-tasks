// Our Tasks: Supabase Edge Function "claude".
// Sends a prompt from the app (Smart add, Create tasks from text) to Claude and returns the answer text.
//
// Deploy: Supabase dashboard > Edge Functions > Deploy a new function > Via Editor > name "claude",
// replace the example code with this file, Deploy.
// Secret: Edge Functions > Secrets > ANTHROPIC_API_KEY = your key from console.anthropic.com.
//
// Only signed-in users of this project get an answer: the function checks the caller's sign-in token
// with Supabase Auth itself, so it doesn't depend on dashboard settings. The API key never leaves the server.

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

// Supabase gives every function its own project's address and service key, so the same code
// works in both projects (production and development). Used to check sign-ins and to record usage.
const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "", { auth: { persistSession: false } });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

// Published prices per million tokens (input, output), for the usage estimate the app shows. Unknown models count as Opus.
const PRICES: Record<string, [number, number]> = { "claude-opus-5-5": [4, 20], "claude-sonnet-5-5": [2, 10], "claude-haiku-5-5": [0.1, 0.5] };
// Records what a call cost (migration 021; before it the insert fails and nothing is counted). Never stops the answer.
async function recordUsage(feature: string, model: string, usage: Record<string, number> | undefined) {
  const [pin, pout] = PRICES[Object.keys(PRICES).find((m) => model?.startsWith(m)) ?? "claude-opus-5-5"];
  const u = usage ?? {}, input = (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) * 1.25 + (u.cache_read_input_tokens ?? 0) * 0.1;
  const cost = (input * pin + (u.output_tokens ?? 0) * pout) / 1e6;
  try { await supabase.from("ai_usage").insert({ feature, model: model || "unknown", input_tokens: u.input_tokens ?? 0, output_tokens: u.output_tokens ?? 0, cost }); } catch {}
}
// The spending limit set at console.anthropic.com is used up: say so plainly instead of a general error.
const limitReached = (e: unknown) => /usage limit|spend limit|credit balance/i.test(e instanceof Error ? e.message : String(e));
const FEATURES = ["smart_add", "from_text", "sort_areas"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);

  // Signed-in users only: the app sends the user's access token; Supabase Auth confirms it.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: auth } = token ? await supabase.auth.getUser(token) : { data: { user: null } };
  if (!auth?.user) return reply({ error: "not_signed_in" }, 401);

  let prompt: unknown, feature: unknown;
  try { ({ prompt, feature } = await req.json()); } catch { return reply({ error: "bad_request" }, 400); }
  if (typeof prompt !== "string" || !prompt.trim() || prompt.length > 60000) return reply({ error: "bad_request" }, 400);

  // Checked per request so a missing secret gives a clear answer instead of a crashed function.
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return reply({ error: "not_configured" }, 503);
  const client = new Anthropic({ apiKey });

  try {
    const response = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      output_config: { effort: "low" }, // short extraction tasks: keep it quick and cheap
      // If a safety classifier declines, retry on Anthropic's recommended fallback model.
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      messages: [{ role: "user", content: prompt }],
    });
    await recordUsage(FEATURES.includes(String(feature)) ? String(feature) : "other", response.model, response.usage as unknown as Record<string, number>);
    if (response.stop_reason === "refusal") return reply({ error: "refused" }, 422);
    const text = response.content.filter((b) => b.type === "text").map((b) => b.text).join("");
    return reply({ text, truncated: response.stop_reason === "max_tokens" });
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) return reply({ error: "rate_limited" }, 429);
    if (e instanceof Anthropic.AuthenticationError) return reply({ error: "not_configured" }, 503);
    if (limitReached(e)) return reply({ error: "limit_reached" }, 402);
    if (e instanceof Anthropic.APIError) return reply({ error: "upstream_error", status: e.status }, 502);
    return reply({ error: "server_error" }, 500);
  }
});
