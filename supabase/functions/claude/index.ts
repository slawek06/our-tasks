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

// Public values (the same ones are in the app's index.html); they grant nothing without a sign-in.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "https://sjtdrnvezorxxdoitszz.supabase.co";
const SUPABASE_KEY = "sb_publishable_M-eM_n6OUMqsPFZyTDk4aw_eh9MUU9A";
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, { auth: { persistSession: false } });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);

  // Signed-in users only: the app sends the user's access token; Supabase Auth confirms it.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: auth } = token ? await supabase.auth.getUser(token) : { data: { user: null } };
  if (!auth?.user) return reply({ error: "not_signed_in" }, 401);

  let prompt: unknown;
  try { ({ prompt } = await req.json()); } catch { return reply({ error: "bad_request" }, 400); }
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
    if (response.stop_reason === "refusal") return reply({ error: "refused" }, 422);
    const text = response.content.filter((b) => b.type === "text").map((b) => b.text).join("");
    return reply({ text, truncated: response.stop_reason === "max_tokens" });
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) return reply({ error: "rate_limited" }, 429);
    if (e instanceof Anthropic.AuthenticationError) return reply({ error: "not_configured" }, 503);
    if (e instanceof Anthropic.APIError) return reply({ error: "upstream_error", status: e.status }, 502);
    return reply({ error: "server_error" }, 500);
  }
});
