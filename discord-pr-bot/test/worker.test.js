// Black-box tests for worker.js: every request goes through the Worker's fetch handler,
// with Discord signatures made by a real Ed25519 key and GitHub/Discord HTTP calls mocked.
// Run with Node 22+:  node --test   (from discord-pr-bot/)

import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import worker from "../worker.js";

const SHA = "a".repeat(40);
const NEW_SHA = "b".repeat(40);
const ORIGIN = "https://bot.example.workers.dev";
const keypair = await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]);
const otherKeys = await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]);
const hex = (buf) => Buffer.from(buf).toString("hex");
const PUBLIC_HEX = hex(await crypto.subtle.exportKey("raw", keypair.publicKey));

let env, ctx, calls, routes;

function makeEnv() {
  const kv = new Map();
  return {
    _kv: kv,
    LINKS: {
      get: async (k) => kv.get(k) ?? null,
      put: async (k, v) => void kv.set(k, v),
      delete: async (k) => void kv.delete(k),
    },
    DISCORD_APPLICATION_ID: "111",
    DISCORD_PUBLIC_KEY: PUBLIC_HEX,
    GITHUB_CLIENT_ID: "Iv1.client",
    GITHUB_CLIENT_SECRET: "client-secret",
    SECRET_KEY: Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString("base64"),
    GITHUB_REPO: "bash-y/repo",
    ALLOWED_GUILD_ID: "999",
    ALLOWED_CHANNEL_ID: "555",
    MERGE_METHOD: "merge",
  };
}

const on = (method, pattern, reply) => routes.unshift([method, pattern, typeof reply === "function" ? reply : () => reply]);

const prData = (o = {}) => ({
  number: 91, node_id: "PR_node91", title: "US-1 #42: Discord update bot", body: "Adds the bot",
  html_url: "https://github.com/bash-y/repo/pull/91", state: "open", draft: false, merged_at: null,
  mergeable: true, mergeable_state: "blocked", user: { login: "bash-y" },
  head: { sha: SHA, ref: "us1-discord-bot" }, base: { ref: "main" }, ...o,
});

let tokenLogin; // which GitHub account the next OAuth exchange belongs to

beforeEach(() => {
  env = makeEnv();
  ctx = { waits: [], waitUntil(p) { this.waits.push(p); } };
  calls = [];
  routes = [];
  tokenLogin = "UiwAntHuynhCIS";
  globalThis.fetch = async (input, init = {}) => {
    const url = typeof input === "string" ? input : input.url;
    const method = (init.method || "GET").toUpperCase();
    const body = init.body ? JSON.parse(init.body) : undefined;
    calls.push({ method, url, body, headers: init.headers || {} });
    for (const [m, pattern, handler] of routes) {
      if (m === method && pattern.test(url)) {
        const [status, data] = await handler({ url, body, headers: init.headers || {} });
        return new Response(data === undefined ? null : JSON.stringify(data), { status });
      }
    }
    throw new Error(`unmocked ${method} ${url}`);
  };
  on("POST", /discord\.com\/api\/v10\/webhooks\//, [200, {}]);
  on("PATCH", /discord\.com\/api\/v10\/webhooks\//, [200, {}]);
  on("POST", /github\.com\/login\/oauth\/access_token/, ({ body }) =>
    [200, { access_token: body.refresh_token ? `ghu_refreshed_${tokenLogin}` : `ghu_${tokenLogin}`,
      refresh_token: `ghr_${tokenLogin}`, expires_in: 28800 }]);
  on("GET", /api\.github\.com\/user$/, ({ headers }) =>
    [200, { login: headers.Authorization.replace("Bearer ghu_", "").replace("refreshed_", "") }]);
  on("GET", /api\.github\.com\/repos\/bash-y\/repo$/, [200, { permissions: { push: true } }]);
  on("GET", /\/pulls\/91$/, [200, prData()]);
  on("GET", /\/pulls\/91\/reviews/, [200, []]);
  on("GET", /\/check-runs/, [200, { check_runs: [{ status: "completed", conclusion: "success" }] }]);
});

async function signed(body, { ts = Math.floor(Date.now() / 1000), key = keypair.privateKey } = {}) {
  const raw = JSON.stringify(body);
  const sig = hex(await crypto.subtle.sign("Ed25519", key, new TextEncoder().encode(ts + raw)));
  return new Request(`${ORIGIN}/interactions`, {
    method: "POST", body: raw,
    headers: { "X-Signature-Ed25519": sig, "X-Signature-Timestamp": String(ts), "content-type": "application/json" },
  });
}

async function send(interaction, opts) {
  const res = await worker.fetch(await signed(interaction, opts), env, ctx);
  const out = res.status === 200 ? await res.json() : { status: res.status };
  await Promise.all(ctx.waits);
  ctx.waits = [];
  return out;
}

const command = (name, options, user = "u-anthony", guild = "999", channel = "555") =>
  ({ type: 2, token: "itok", guild_id: guild, channel_id: channel, member: { user: { id: user } }, data: { name, options } });
const button = (custom_id, user = "u-anthony", values) =>
  ({ type: 3, token: "itok", guild_id: "999", channel_id: "555", member: { user: { id: user } }, data: { custom_id, values } });

async function link(user = "u-anthony", login = "UiwAntHuynhCIS") {
  tokenLogin = login;
  const res = await send(command("link", undefined, user));
  const url = new URL(res.data.components[0].components[0].url);
  const back = await worker.fetch(
    new Request(`${ORIGIN}/github/callback?code=c1&state=${encodeURIComponent(url.searchParams.get("state"))}`), env, ctx);
  assert.equal(back.status, 200, await back.clone().text());
  return url;
}

const discordCalls = (method) => calls.filter((c) => c.method === method && c.url.includes("discord.com"));
const lastEdit = () => discordCalls("PATCH").at(-1).body;
const buttonsOf = (msg) => msg.components[0].components;

// ----------------------------------------------------------------------------- signatures

test("rejects requests that Discord did not sign", async () => {
  assert.equal((await send({ type: 1 }, { key: otherKeys.privateKey })).status, 401);
  const unsigned = new Request(`${ORIGIN}/interactions`, { method: "POST", body: JSON.stringify({ type: 1 }) });
  assert.equal((await worker.fetch(unsigned, env, ctx)).status, 401);
});

test("rejects replayed requests with an old timestamp", async () => {
  assert.equal((await send({ type: 1 }, { ts: Math.floor(Date.now() / 1000) - 600 })).status, 401);
});

test("answers Discord's PING so the endpoint URL can be saved", async () => {
  assert.deepEqual(await send({ type: 1 }), { type: 1 });
});

test("only works in the team server", async () => {
  const res = await send(command("whoami", undefined, "u-anthony", "123"));
  assert.match(res.data.content, /only works in the SwagPc team server/);
  assert.equal(res.data.flags, 64);
});

test("only works in the configured channel", async () => {
  const res = await send(command("whoami", undefined, "u-anthony", "999", "777"));
  assert.match(res.data.content, /only works in <#555>/);
  assert.equal(res.data.flags, 64);
  const ok = await send(command("whoami"));
  assert.doesNotMatch(ok.data.content, /only works/);
});

// ----------------------------------------------------------------------------- linking

test("/link gives a private GitHub sign-in button bound to the caller", async () => {
  const res = await send(command("link"));
  assert.equal(res.data.flags, 64);
  const url = new URL(res.data.components[0].components[0].url);
  assert.equal(url.origin + url.pathname, "https://github.com/login/oauth/authorize");
  assert.equal(url.searchParams.get("client_id"), "Iv1.client");
  assert.equal(url.searchParams.get("redirect_uri"), `${ORIGIN}/github/callback`);
  assert.ok(url.searchParams.get("state"));
});

test("sign-in links the account and stores tokens encrypted", async () => {
  await link();
  const stored = env._kv.get("user:u-anthony");
  assert.ok(stored);
  assert.ok(!stored.includes("ghu_"), "access token must not be stored in plain text");
  assert.ok(!stored.includes("ghr_"), "refresh token must not be stored in plain text");
  const res = await send(command("whoami"));
  assert.match(res.data.content, /Anthony Huynh.*@UiwAntHuynhCIS/);
});

test("a forged or tampered /link state is refused", async () => {
  const url = await link();
  env._kv.clear();
  const state = url.searchParams.get("state");
  const tampered = state.slice(0, -2) + (state.endsWith("AA") ? "BB" : "AA");
  const res = await worker.fetch(new Request(`${ORIGIN}/github/callback?code=c&state=${tampered}`), env, ctx);
  assert.equal(res.status, 400);
  assert.equal(env._kv.size, 0);
});

test("a record copied onto another Discord user cannot be decrypted", async () => {
  await link();
  env._kv.set("user:u-mallory", env._kv.get("user:u-anthony"));
  const res = await send(command("whoami", undefined, "u-mallory"));
  assert.match(res.data.content, /haven't linked/);
});

test("accounts without access to the repo are not linked", async () => {
  on("GET", /api\.github\.com\/repos\/bash-y\/repo$/, [404, { message: "Not Found" }]);
  const res = await send(command("link"));
  const state = new URL(res.data.components[0].components[0].url).searchParams.get("state");
  const back = await worker.fetch(new Request(`${ORIGIN}/github/callback?code=c&state=${encodeURIComponent(state)}`), env, ctx);
  assert.equal(back.status, 403);
  assert.equal(env._kv.size, 0);
});

test("/unlink forgets the account", async () => {
  await link();
  await send(command("unlink"));
  assert.equal(env._kv.size, 0);
});

test("expired GitHub tokens are refreshed before use", async () => {
  on("POST", /github\.com\/login\/oauth\/access_token/, ({ body }) =>
    [200, { access_token: body.refresh_token ? "ghu_refreshed_UiwAntHuynhCIS" : "ghu_UiwAntHuynhCIS",
      refresh_token: "ghr_next", expires_in: body.refresh_token ? 28800 : 30 }]);
  await link();
  await send(command("pr", [{ name: "number", value: 91 }]));
  const refresh = calls.find((c) => c.url.includes("access_token") && c.body?.grant_type === "refresh_token");
  assert.ok(refresh, "refresh request sent");
  const prRead = calls.find((c) => c.url.endsWith("/pulls/91"));
  assert.equal(prRead.headers.Authorization, "Bearer ghu_refreshed_UiwAntHuynhCIS");
});

// ----------------------------------------------------------------------------- cards

test("commands that act on GitHub require a linked account", async () => {
  const res = await send(command("pr", [{ name: "number", value: 91 }]));
  assert.match(res.data.content, /\/link/);
  assert.equal(res.data.flags, 64);
});

test("/pr posts a card with Approve, Merge, Refresh and a review link", async () => {
  await link();
  const res = await send(command("pr", [{ name: "number", value: 91 }]));
  assert.equal(res.type, 5);
  const msg = lastEdit();
  const e = msg.embeds[0];
  assert.equal(e.title, "PR #91: US-1 #42: Discord update bot");
  const fields = Object.fromEntries(e.fields.map((f) => [f.name, f.value]));
  assert.equal(fields.Author, "Sebastian Cadena");
  assert.equal(fields.Reviews, "⏳ No approval yet");
  assert.match(fields.Merge, /needs an approval/);
  assert.equal(fields.Checks, "✅ 1 passed");
  assert.deepEqual(buttonsOf(msg).map((b) => b.custom_id || b.url),
    [`approve:91:${SHA}`, `merge:91:${SHA}`, "refresh:91", "https://github.com/bash-y/repo/pull/91/files"]);
  assert.deepEqual(msg.allowed_mentions, { parse: [] });
});

test("/prs lists open PRs with a picker that opens a card", async () => {
  await link();
  on("GET", /\/pulls\?state=open/, [200, [prData(), prData({ number: 92, title: "Draft thing", draft: true, user: { login: "joromanii" } })]]);
  await send(command("prs"));
  const msg = lastEdit();
  assert.match(msg.embeds[0].description, /#91.*Sebastian Cadena/);
  assert.match(msg.embeds[0].description, /#92.*Jomar Rodriguez Canales · 📝 draft/);
  assert.deepEqual(msg.components[0].components[0].options.map((o) => o.value), ["91", "92"]);
  await send(button("pick", "u-anthony", ["91"]));
  assert.equal(lastEdit().embeds[0].title, "PR #91: US-1 #42: Discord update bot");
});

// ----------------------------------------------------------------------------- approve

test("Approve files a review as the person who clicked, pinned to the shown commit", async () => {
  await link();
  let review;
  on("POST", /\/pulls\/91\/reviews$/, ({ body, headers }) => { review = { body, auth: headers.Authorization }; return [200, {}]; });
  const res = await send(button(`approve:91:${SHA}`));
  assert.equal(res.type, 6);
  assert.equal(review.auth, "Bearer ghu_UiwAntHuynhCIS");
  assert.equal(review.body.event, "APPROVE");
  assert.equal(review.body.commit_id, SHA);
  assert.ok(lastEdit().embeds, "card refreshed after approving");
});

test("the refreshed card shows who approved", async () => {
  await link();
  on("POST", /\/pulls\/91\/reviews$/, [200, {}]);
  on("GET", /\/pulls\/91\/reviews/, [200, [{ state: "APPROVED", user: { login: "UiwAntHuynhCIS" } }]]);
  await send(button(`approve:91:${SHA}`));
  const fields = Object.fromEntries(lastEdit().embeds[0].fields.map((f) => [f.name, f.value]));
  assert.equal(fields.Reviews, "✅ Approved by Anthony Huynh");
});

test("Approve on an out-of-date card does not approve unseen commits", async () => {
  await link();
  on("GET", /\/pulls\/91$/, [200, prData({ head: { sha: NEW_SHA, ref: "us1-discord-bot" } })]);
  await send(button(`approve:91:${SHA}`));
  assert.ok(!calls.some((c) => c.method === "POST" && c.url.endsWith("/reviews")), "no review filed");
  const note = discordCalls("POST").at(-1).body;
  assert.match(note.content, /new commits/);
  assert.equal(note.flags, 64);
  assert.equal(buttonsOf(lastEdit())[0].custom_id, `approve:91:${NEW_SHA}`);
});

test("GitHub's refusal is shown privately, e.g. approving your own PR", async () => {
  await link("u-seb", "bash-y");
  on("POST", /\/pulls\/91\/reviews$/, [422, { message: "Unprocessable Entity", errors: ["Can not approve your own pull request"] }]);
  await send(button(`approve:91:${SHA}`, "u-seb"));
  const note = discordCalls("POST").at(-1).body;
  assert.match(note.content, /Can not approve your own pull request/);
  assert.equal(note.flags, 64);
});

// ----------------------------------------------------------------------------- drafts

test("a draft card offers Ready for review instead of Approve and Merge", async () => {
  await link();
  on("GET", /\/pulls\/91$/, [200, prData({ draft: true, mergeable_state: "draft" })]);
  await send(command("pr", [{ name: "number", value: 91 }]));
  const ids = buttonsOf(lastEdit()).map((b) => b.custom_id || b.url);
  assert.deepEqual(ids, [`ready:91:${SHA}`, "refresh:91", "https://github.com/bash-y/repo/pull/91/files"]);
});

test("Ready for review marks the draft ready as the clicker, then the card offers Approve", async () => {
  await link();
  let draft = true, mutation;
  on("GET", /\/pulls\/91$/, () => [200, prData({ draft, mergeable_state: draft ? "draft" : "blocked" })]);
  on("POST", /api\.github\.com\/graphql$/, ({ body, headers }) => {
    mutation = { body, auth: headers.Authorization };
    draft = false;
    return [200, { data: { markPullRequestReadyForReview: { pullRequest: { isDraft: false } } } }];
  });
  const res = await send(button(`ready:91:${SHA}`));
  assert.equal(res.type, 6);
  assert.equal(mutation.auth, "Bearer ghu_UiwAntHuynhCIS");
  assert.match(mutation.body.query, /markPullRequestReadyForReview/);
  assert.deepEqual(mutation.body.variables, { id: "PR_node91" });
  assert.equal(buttonsOf(lastEdit())[0].custom_id, `approve:91:${SHA}`);
});

test("a refused Ready for review is reported privately", async () => {
  await link();
  on("GET", /\/pulls\/91$/, [200, prData({ draft: true })]);
  on("POST", /api\.github\.com\/graphql$/, [200, { errors: [{ message: "Resource not accessible by integration" }] }]);
  await send(button(`ready:91:${SHA}`));
  const note = discordCalls("POST").at(-1).body;
  assert.match(note.content, /Resource not accessible by integration/);
  assert.equal(note.flags, 64);
});

// ----------------------------------------------------------------------------- merge

test("Merge asks for confirmation first and touches nothing", async () => {
  await link();
  const before = calls.length;
  const res = await send(button(`merge:91:${SHA}`));
  assert.equal(res.data.flags, 64);
  assert.deepEqual(buttonsOf(res.data).map((b) => b.custom_id), [`confirm:91:${SHA}`, "cancel"]);
  assert.equal(calls.length, before, "no GitHub or Discord calls");
});

test("Confirm merges as the clicker, only if the head is unchanged, and tells the channel", async () => {
  await link("u-seb", "bash-y");
  let merge;
  on("PUT", /\/pulls\/91\/merge$/, ({ body, headers }) => { merge = { body, auth: headers.Authorization }; return [200, { sha: "c".repeat(40), merged: true }]; });
  await send(button(`confirm:91:${SHA}`, "u-seb"));
  assert.equal(merge.auth, "Bearer ghu_bash-y");
  assert.deepEqual(merge.body, { sha: SHA, merge_method: "merge" });
  assert.match(lastEdit().content, /Merged PR #91/);
  const announce = discordCalls("POST").at(-1).body;
  assert.match(announce.content, /PR #91\*\* was merged by \*\*Sebastian Cadena\*\* from Discord/);
  assert.equal(announce.flags, undefined, "announcement is public");
  assert.deepEqual(announce.allowed_mentions, { parse: [] });
});

test("a merge GitHub refuses (no approval yet) is reported privately", async () => {
  await link();
  on("PUT", /\/pulls\/91\/merge$/, [405, { message: "At least 1 approving review is required by reviewers with write access." }]);
  await send(button(`confirm:91:${SHA}`));
  const note = discordCalls("POST").at(-1).body;
  assert.match(note.content, /At least 1 approving review is required/);
  assert.equal(note.flags, 64);
});

test("Cancel closes the confirmation", async () => {
  const res = await send(button("cancel"));
  assert.equal(res.type, 7);
  assert.deepEqual(res.data.components, []);
});

test("unknown or malformed buttons are refused", async () => {
  await link();
  for (const id of ["delete:91", "approve:91", "merge:abc:" + SHA, "approve:91:notasha"]) {
    const res = await send(button(id));
    assert.match(res.data.content, /out of date/, id);
  }
  assert.ok(!calls.some((c) => ["PUT", "DELETE"].includes(c.method)));
});

test("a reply Discord rejects is replaced with plain text instead of hanging on 'thinking'", async () => {
  await link();
  let patches = 0;
  on("PATCH", /discord\.com\/api\/v10\/webhooks\//, ({ body }) => (++patches === 1 ? [400, { message: "Invalid emoji" }] : [200, {}]));
  await send(command("pr", [{ name: "number", value: 91 }]));
  const edits = discordCalls("PATCH");
  assert.equal(edits.length, 2);
  assert.ok(edits[0].body.embeds, "first try is the rich card");
  assert.deepEqual(edits[1].body.embeds, []);
  assert.deepEqual(edits[1].body.components, []);
  assert.match(edits[1].body.content, /Discord rejected the bot's reply/);
});

test("worker.js is pure ASCII, so copy-paste into the Cloudflare editor cannot garble it", async () => {
  const { readFile } = await import("node:fs/promises");
  const src = await readFile(new URL("../worker.js", import.meta.url));
  const bad = [...src].findIndex((b) => b > 127);
  assert.equal(bad, -1, `non-ASCII byte at offset ${bad}`);
});

// ----------------------------------------------------------------------------- routes

test("health check and unknown routes", async () => {
  assert.equal(await (await worker.fetch(new Request(`${ORIGIN}/`), env, ctx)).text(), "SwagPc PR Bot is running.");
  assert.equal((await worker.fetch(new Request(`${ORIGIN}/nope`), env, ctx)).status, 404);
});
