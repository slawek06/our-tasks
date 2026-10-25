// Our Tasks: Supabase Edge Function "notify".
// Push notifications, the morning/evening briefings written by Claude, and the briefing chat.
//
// Deploy: Supabase dashboard > Edge Functions > Deploy a new function > Via Editor > name "notify",
// replace the example code with this file, Deploy. If the function's settings show "Verify JWT"
// (or "Enforce JWT verification"), switch it OFF: the timer calls this function without a sign-in,
// and the function checks every caller itself (a signed-in user, or the timer's secret).
// Needs: the database update supabase/migrations/004_notifications.sql, and the ANTHROPIC_API_KEY secret.
//
// Actions (POST JSON body {action, ...}):
//   vapid      signed-in  -> the public key the app needs to subscribe a device
//   test       signed-in  -> sends "Notifications work" to the caller's devices
//   event      signed-in  -> {type: assigned|comment|closed, taskId, text?}: notifies the other person
//   brief_now  signed-in  -> writes a briefing for the caller now (no push)
//   chat       signed-in  -> {message}: replies, and may propose changes the app shows for confirmation
//   tick       timer      -> sends the briefings that are due (called every 15 minutes by pg_cron)

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "https://sjtdrnvezorxxdoitszz.supabase.co";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const APP_URL = "https://slawek06.github.io/our-tasks/";
// The service role reads everything; every query below therefore filters by the caller (private tasks by owner).
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
type Turn = { role: "user" | "assistant"; content: string };
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

// ---- web push (RFC 8291 message encryption, RFC 8292 VAPID), WebCrypto only ----
const enc = new TextEncoder();
const b64u = (buf: ArrayBuffer | Uint8Array) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const unb64u = (s: string) => {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
};
const concat = (...parts: Uint8Array[]) => {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
};
async function hmac(key: Uint8Array, data: Uint8Array) {
  const k = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, data));
}
async function generateVapid() {
  const kp = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  return { publicKey: b64u(await crypto.subtle.exportKey("raw", kp.publicKey)), privateJwk: await crypto.subtle.exportKey("jwk", kp.privateKey) };
}
async function vapidAuth(endpoint: string, vapid: { publicKey: string; privateJwk: JsonWebKey }) {
  const head = b64u(enc.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const claims = b64u(enc.encode(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: APP_URL })));
  const key = await crypto.subtle.importKey("jwk", vapid.privateJwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(head + "." + claims));
  return `vapid t=${head}.${claims}.${b64u(sig)}, k=${vapid.publicKey}`;
}
async function encryptPayload(payload: string, p256dh: string, authSecret: string) {
  const uaPublic = unb64u(p256dh), auth = unb64u(authSecret);
  const as = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]);
  const asPublic = new Uint8Array(await crypto.subtle.exportKey("raw", as.publicKey));
  const uaKey = await crypto.subtle.importKey("raw", uaPublic, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const secret = new Uint8Array(await crypto.subtle.deriveBits({ name: "ECDH", public: uaKey }, as.privateKey, 256));
  const ikm = await hmac(await hmac(auth, secret), concat(enc.encode("WebPush: info\0"), uaPublic, asPublic, new Uint8Array([1])));
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const prk = await hmac(salt, ikm);
  const cek = (await hmac(prk, concat(enc.encode("Content-Encoding: aes128gcm\0"), new Uint8Array([1])))).slice(0, 16);
  const nonce = (await hmac(prk, concat(enc.encode("Content-Encoding: nonce\0"), new Uint8Array([1])))).slice(0, 12);
  const key = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  const sealed = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, concat(enc.encode(payload), new Uint8Array([2]))));
  return concat(salt, new Uint8Array([0, 0, 16, 0]), new Uint8Array([asPublic.length]), asPublic, sealed); // record size 4096
}
// ---- end of web push ----

async function getVapid() {
  const { data } = await db.from("push_config").select("vapid").eq("id", 1).maybeSingle();
  if (data?.vapid) return data.vapid;
  const vapid = await generateVapid();
  await db.from("push_config").upsert({ id: 1, vapid });
  return vapid;
}
// Sends one notification to every device of a user; removes devices the push service says are gone.
async function pushTo(userId: string, message: { title: string; body: string; url?: string; tag?: string }) {
  const { data: subs } = await db.from("push_subscriptions").select("*").eq("user_id", userId);
  if (!subs?.length) return 0;
  const vapid = await getVapid();
  let sent = 0;
  for (const s of subs) {
    try {
      const res = await fetch(s.endpoint, {
        method: "POST",
        headers: { Authorization: await vapidAuth(s.endpoint, vapid), "Content-Encoding": "aes128gcm", "Content-Type": "application/octet-stream", TTL: "43200", Urgency: "normal" },
        body: await encryptPayload(JSON.stringify(message), s.p256dh, s.auth),
      });
      if (res.status === 404 || res.status === 410) await db.from("push_subscriptions").delete().eq("id", s.id);
      else if (res.ok) sent++;
    } catch { /* one device failing shouldn't stop the others */ }
  }
  return sent;
}

// ---- who's who, settings, local time ----
async function people() {
  const { data } = await db.from("config").select("value").eq("key", "people").maybeSingle();
  return (data?.value ?? {}) as { a?: string; b?: string; aUser?: string; bUser?: string };
}
const slotOf = (p: Awaited<ReturnType<typeof people>>, uid: string) => (p.aUser === uid ? "a" : p.bUser === uid ? "b" : "");
const nameOf = (p: Awaited<ReturnType<typeof people>>, slot: string) => (slot === "a" ? p.a : slot === "b" ? p.b : slot === "both" ? "both of you" : "") || "";
const PREF_DEFAULTS = { lang: "en", tz: "Europe/Warsaw", morning: "07:30", evening: "20:00", quiet_from: "22:00", quiet_to: "07:00", on_assigned: true, on_comment: true, on_closed: true, morning_sent: "", evening_sent: "" };
async function prefsOf(uid: string) {
  const { data } = await db.from("notify_prefs").select("*").eq("user_id", uid).maybeSingle();
  return { ...PREF_DEFAULTS, ...(data ?? {}), user_id: uid };
}
function localNow(tz: string) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-GB", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", weekday: "long", hour12: false })
    .formatToParts(new Date()).map((x) => [x.type, x.value]));
  return { date: `${parts.year}-${parts.month}-${parts.day}`, time: `${parts.hour === "24" ? "00" : parts.hour}:${parts.minute}`, weekday: parts.weekday };
}
const inQuiet = (p: typeof PREF_DEFAULTS, time: string) =>
  p.quiet_from && p.quiet_to && (p.quiet_from <= p.quiet_to ? time >= p.quiet_from && time < p.quiet_to : time >= p.quiet_from || time < p.quiet_to);

// ---- what Claude sees: the caller's open tasks, shopping and recent activity ----
async function snapshot(uid: string) {
  const [ppl, tasksRes, itemsRes, listsRes, stateRes, histRes] = await Promise.all([
    people(),
    db.from("tasks").select("*").eq("archived", false),
    db.from("items").select("*").eq("bought", false),
    db.from("lists").select("*"),
    db.from("user_state").select("today").eq("user_id", uid).maybeSingle(),
    db.from("history").select("*").gt("at", Date.now() - 36 * 3600 * 1000).order("at", { ascending: false }).limit(25),
  ]);
  const prefs = await prefsOf(uid);
  const now = localNow(prefs.tz);
  const me = slotOf(ppl, uid);
  const all = (tasksRes.data ?? []).filter((t) => !t.private || t.owner === uid); // never another person's private tasks
  const byId = new Map(all.map((t) => [t.id, t]));
  const path = (t: { parent_id: string }) => { const n: string[] = []; for (let p = byId.get(t.parent_id); p; p = byId.get(p.parent_id)) n.unshift(p.title); return n.join(" > "); };
  const pins = (stateRes.data?.today ?? {}) as Record<string, string>;
  const open = all.filter((t) => t.status !== "done");
  const lines = open.slice(0, 250).map((t) => [
    `id=${t.id}`, `"${t.title}"`, t.status === "doing" ? "in progress" : "not started",
    t.due ? `due ${t.due}${t.due < now.date ? " (OVERDUE)" : t.due === now.date ? " (TODAY)" : ""}` : "no due date",
    t.private ? "private" : t.assignee ? `for ${nameOf(ppl, t.assignee)}` : "unassigned",
    t.priority !== "normal" ? `${t.priority} priority` : "", path(t) ? `under ${path(t)}` : "", pins[t.id] === now.date ? "in MY DAY" : "",
  ].filter(Boolean).join(" | "));
  const listName = new Map((listsRes.data ?? []).map((l) => [l.id, l.name]));
  const shopping = new Map<string, string[]>();
  for (const i of itemsRes.data ?? []) {
    const ln = listName.get(i.list_id) ?? "Groceries";
    if (!shopping.has(ln)) shopping.set(ln, []);
    shopping.get(ln)!.push(i.name + (i.qty ? ` (quantity: ${i.qty})` : "") + (i.checked ? " (already in the basket)" : ""));
  }
  const lists = [{ id: "groceries", name: "Groceries" }, ...(listsRes.data ?? []).filter((l) => l.id !== "groceries")];
  const activity = (histRes.data ?? []).filter((h) => byId.has(h.task_id) || !h.task_id).map((h) => `${nameOf(ppl, h.author) || "Someone"} ${h.text} ("${h.title}")`);
  const text = [
    `People: "a" = ${ppl.a}, "b" = ${ppl.b}. You are talking to ${nameOf(ppl, me) || "one of them"} ("${me}").`,
    `Now: ${now.weekday} ${now.date}, ${now.time} (${prefs.tz}).`,
    `Open tasks (${open.length}):`, ...(lines.length ? lines : ["(none)"]),
    `Shopping lists (ids: ${lists.map((l) => `${l.name}=${l.id}`).join(", ")}):`,
    ...([...shopping].map(([ln, xs]) => `${ln}: ${xs.join(", ")}`) || []), ...(shopping.size ? [] : ["(all empty)"]),
    `Recent activity (last 36 h): ${activity.length ? activity.join("; ") : "none"}`,
  ].join("\n");
  return { ppl, me, myName: nameOf(ppl, me) || "there", now, prefs, text, byId, lists, open };
}

async function askClaude(system: string, messages: Turn[], schema: Record<string, unknown>) {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) throw new Error("not_configured");
  const client = new Anthropic({ apiKey });
  const response = await client.beta.messages.create({
    model: "claude-opus-5-5",
    max_tokens: 16000,
    system,
    messages,
    output_config: { effort: "low", format: { type: "json_schema", schema } },
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
  });
  if (response.stop_reason === "refusal") throw new Error("refused");
  return JSON.parse(response.content.filter((b) => b.type === "text").map((b) => b.text).join(""));
}

// Briefings and replies are also read aloud by the app, so they must sound natural when spoken.
const SPOKEN_STYLE =
  "Your text is shown in the app and also read aloud by a speech voice, so write natural spoken sentences: " +
  "no symbols or shorthand (never \"x4\", \"×\", \"/\", \"&\", bullets, emoji or abbreviations like \"pcs\"); " +
  "say quantities the way a person would (\"four kilos of potatoes\" when a unit is given, otherwise \"four potatoes\"; skip a quantity of one); " +
  "don't read out whole lists: summarise and name at most two or three items (\"six things on Groceries, including potatoes and herring\"); " +
  "write dates as words (\"on Friday\", \"tomorrow\"), not as numbers.";
const LANGUAGE = { en: "English", pl: "Polish" } as Record<string, string>;

// ---- briefings ----
const BRIEFING_SCHEMA = {
  type: "object",
  properties: { push: { type: "string" }, briefing: { type: "string" } },
  required: ["push", "briefing"], additionalProperties: false,
};
async function writeBriefing(uid: string, kind: "morning" | "evening") {
  const s = await snapshot(uid);
  const todayOpen = s.open.filter((t) => (t.due && t.due <= s.now.date) || false);
  if (kind === "evening" && !todayOpen.length) return null; // nothing left today: no evening message
  const system = `You are the friendly assistant inside "Our Tasks", a shared task and shopping app for ${s.ppl.a} and ${s.ppl.b}. ` +
    `You write ${s.myName}'s ${kind === "morning" ? "morning briefing" : "evening check"}.`;
  const ask = `${s.text}\n\n` + (kind === "morning"
    ? `Write ${s.myName}'s morning briefing: friendly and short, 2-4 sentences, like a helpful partner. Lead with what matters most today for ${s.myName} (overdue first, then due today and MY DAY picks), and give one practical tip, for example combining an errand with an open shopping list or a related task. Mention ${s.me === "a" ? s.ppl.b : s.ppl.a}'s day only if it helps coordinate.`
    : `Write ${s.myName}'s evening check: friendly and short, 2-3 sentences. Say what's still open for today and suggest what to move or do first tomorrow.`) +
    ` Use task titles as written (they may be Polish), but you may inflect them to fit the sentence; never invent tasks. Write in ${LANGUAGE[s.prefs.lang] || "English"}. Don't start with a greeting line of its own. ${SPOKEN_STYLE}` +
    ` Also write "push": a one-line summary for the lock screen, at most 110 characters.`;
  const out = await askClaude(system, [{ role: "user", content: ask }], BRIEFING_SCHEMA);
  const briefing = String(out.briefing || "").trim(), push = String(out.push || "").trim().slice(0, 140);
  if (!briefing) return null;
  const { data: row } = await db.from("briefings").insert({ user_id: uid, kind, role: "assistant", text: briefing }).select().single();
  return { row, push, name: s.myName };
}

// ---- chat ----
const ACTION_TYPES = ["complete", "set_due", "assign", "add_task", "add_item", "pin_today"];
const CHAT_SCHEMA = {
  type: "object",
  properties: {
    reply: { type: "string" },
    actions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          type: { type: "string", enum: ACTION_TYPES },
          label: { type: "string" },
          taskId: { type: "string" }, title: { type: "string" }, due: { type: "string" },
          assignee: { type: "string" }, parentId: { type: "string" }, text: { type: "string" }, listId: { type: "string" },
        },
        required: ["type", "label", "taskId", "title", "due", "assignee", "parentId", "text", "listId"],
        additionalProperties: false,
      },
    },
  },
  required: ["reply", "actions"], additionalProperties: false,
};
async function chat(uid: string, message: string) {
  await db.from("briefings").insert({ user_id: uid, kind: "chat", role: "user", text: message });
  const s = await snapshot(uid);
  const { data: rows } = await db.from("briefings").select("*").eq("user_id", uid).order("created_at", { ascending: false }).limit(24);
  const history: Turn[] = [];
  for (const r of (rows ?? []).reverse()) {
    const role = r.role === "assistant" ? "assistant" : "user";
    const proposed = Array.isArray(r.actions) && r.actions.length ? `\n(Proposed changes: ${r.actions.map((a: { label: string }) => a.label).join("; ")}${r.applied ? " - handled" : ""})` : "";
    const content = r.text + proposed;
    const last = history[history.length - 1];
    if (last && last.role === role) last.content += "\n\n" + content; // merge same-role turns
    else history.push({ role, content });
  }
  if (history[0]?.role === "assistant") history.unshift({ role: "user", content: "Give me my briefing." });
  const system = `You are the friendly assistant inside "Our Tasks", a shared task and shopping app for ${s.ppl.a} and ${s.ppl.b}. ` +
    `You are chatting with ${s.myName}. Reply conversationally and briefly (usually 1-4 sentences), in the language of ${s.myName}'s last message (${LANGUAGE[s.prefs.lang] || "English"} if unclear). Use task titles as written; never invent tasks. ${SPOKEN_STYLE}\n` +
    `You can PROPOSE changes in "actions"; the app shows them to ${s.myName}, who confirms. Never say a change is done; say you've suggested it.\n` +
    `Action types (fill unused fields with ""): complete {taskId}; set_due {taskId, due "YYYY-MM-DD" or "" to remove}; assign {taskId, assignee "a"|"b"|"both"|""}; ` +
    `add_task {title, due, assignee, parentId}; add_item {text like "2 milk", listId}; pin_today {taskId} (adds to MY DAY). ` +
    `"label" is a short human description, e.g. "Move \\"Dentist\\" to Fri 31 Oct". Only use ids from the data. Propose nothing when ${s.myName} only asks a question.\n` +
    `You can't delete tasks or change private tasks of the other person; say so if asked.\n\nCurrent data:\n${s.text}`;
  const out = await askClaude(system, history, CHAT_SCHEMA);
  const listIds = new Set(s.lists.map((l) => l.id));
  const actions = (Array.isArray(out.actions) ? out.actions : []).filter((a: Record<string, string>) => {
    if (!ACTION_TYPES.includes(a.type) || !a.label) return false;
    if (["complete", "set_due", "assign", "pin_today"].includes(a.type)) {
      if (!s.byId.has(a.taskId)) return false;
      if (a.type === "assign") return !s.byId.get(a.taskId)?.private && ["a", "b", "both", ""].includes(a.assignee);
      if (a.type === "set_due") return !a.due || /^\d{4}-\d{2}-\d{2}$/.test(a.due);
      return true;
    }
    if (a.type === "add_task") return !!a.title.trim();
    if (a.type === "add_item") { if (!listIds.has(a.listId)) a.listId = "groceries"; return !!a.text.trim(); }
    return true;
  }).slice(0, 10);
  const { data: row } = await db.from("briefings").insert({ user_id: uid, kind: "chat", role: "assistant", text: String(out.reply || "").trim() || "OK.", actions }).select().single();
  return row;
}

// ---- requests ----
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);
  if (!SERVICE_KEY) return reply({ error: "not_configured", detail: "SUPABASE_SERVICE_ROLE_KEY is missing" }, 503);
  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { return reply({ error: "bad_request" }, 400); }

  try {
    // Timer: send the briefings that are due.
    if (body.action === "tick") {
      const { data: cfg } = await db.from("push_config").select("cron_secret").eq("id", 1).maybeSingle();
      if (!cfg?.cron_secret || req.headers.get("x-cron-secret") !== cfg.cron_secret) return reply({ error: "forbidden" }, 403);
      const ppl = await people(), done: string[] = [];
      for (const uid of [ppl.aUser, ppl.bUser].filter(Boolean) as string[]) {
        const { count } = await db.from("push_subscriptions").select("id", { count: "exact", head: true }).eq("user_id", uid);
        if (!count) continue; // nobody to notify on this person's devices
        const p = await prefsOf(uid), now = localNow(p.tz);
        for (const kind of ["morning", "evening"] as const) {
          const at = p[kind], sentKey = kind === "morning" ? "morning_sent" : "evening_sent";
          // Due when the time has passed today and it hasn't gone out; skip if more than 3 hours late (timer was down).
          if (!at || p[sentKey] === now.date || now.time < at) continue;
          const [h, m] = at.split(":").map(Number), [nh, nm] = now.time.split(":").map(Number);
          await db.from("notify_prefs").upsert({ user_id: uid, [sentKey]: now.date });
          if ((nh * 60 + nm) - (h * 60 + m) > 180) continue;
          const b = await writeBriefing(uid, kind);
          if (!b) continue;
          const pl = p.lang === "pl";
          const title = kind === "morning" ? (pl ? `Dzień dobry, ${b.name}` : `Good morning, ${b.name}`) : (pl ? "Wieczorne podsumowanie" : "Evening check");
          await pushTo(uid, { title, body: b.push || b.row.text.slice(0, 120), url: APP_URL + "?briefing=1", tag: "briefing" });
          done.push(`${kind}:${uid}`);
        }
      }
      return reply({ ok: true, sent: done });
    }

    // Everything else: signed-in users only.
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: auth } = token ? await db.auth.getUser(token) : { data: { user: null } };
    const uid = auth?.user?.id;
    if (!uid) return reply({ error: "not_signed_in" }, 401);

    if (body.action === "vapid") return reply({ publicKey: (await getVapid()).publicKey });
    if (body.action === "test") return reply({ sent: await pushTo(uid, { title: "Our Tasks", body: "Notifications work on this device.", url: APP_URL, tag: "test" }) });

    if (body.action === "event") {
      const { data: task } = await db.from("tasks").select("*").eq("id", String(body.taskId ?? "")).maybeSingle();
      if (!task || task.private) return reply({ sent: 0 });
      const ppl = await people(), sender = slotOf(ppl, uid);
      const other = sender === "a" ? ppl.bUser : sender === "b" ? ppl.aUser : "";
      const otherSlot = sender === "a" ? "b" : "a";
      if (!other || other === uid) return reply({ sent: 0 });
      const p = await prefsOf(other);
      if (inQuiet(p, localNow(p.tz).time)) return reply({ sent: 0, quiet: true });
      const who = nameOf(ppl, sender) || "Someone", url = APP_URL + "?task=" + encodeURIComponent(task.id);
      let message: { title: string; body: string } | null = null;
      if (body.type === "assigned" && p.on_assigned && [otherSlot, "both"].includes(task.assignee))
        message = { title: `${who} assigned you a task`, body: task.title + (task.due ? ` (due ${task.due})` : "") };
      else if (body.type === "comment" && p.on_comment)
        message = { title: `${who} commented on ${task.title}`, body: String(body.text ?? "").slice(0, 160) };
      else if (body.type === "closed" && p.on_closed)
        message = { title: `${who} closed a task`, body: task.title };
      return reply({ sent: message ? await pushTo(other, { ...message, url, tag: `${body.type}-${task.id}` }) : 0 });
    }

    if (body.action === "brief_now") {
      const b = await writeBriefing(uid, "morning"); // on demand: the full "what matters today" briefing, no push
      return reply({ row: b?.row ?? null });
    }

    if (body.action === "chat") {
      const message = String(body.message ?? "").trim().slice(0, 2000);
      if (!message) return reply({ error: "bad_request" }, 400);
      return reply({ row: await chat(uid, message) });
    }
    return reply({ error: "unknown_action" }, 400);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === "not_configured") return reply({ error: "not_configured" }, 503);
    if (e instanceof Anthropic.RateLimitError) return reply({ error: "rate_limited" }, 429);
    return reply({ error: "server_error", detail: msg.slice(0, 200) }, 500);
  }
});
