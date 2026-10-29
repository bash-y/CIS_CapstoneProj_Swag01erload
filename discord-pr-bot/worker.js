/**
 * SwagPc PR Bot: review, approve and merge pull requests from Discord.
 *
 * Runs as a Cloudflare Worker. Discord sends every slash command and button click to
 * /interactions. Each teammate links their own GitHub account once with /link; after that,
 * Approve and Merge act as that person, so GitHub records the real reviewer and merger and
 * main's ruleset (1 approval from someone other than the author) still applies.
 *
 * Routes
 *   POST /interactions     Discord interactions (Ed25519 signature checked on every request)
 *   GET  /github/callback  GitHub sign-in redirect used by /link
 *   GET  /                 health check
 *
 * Settings (Cloudflare dashboard -> Worker -> Settings; setup in wiki/Discord-PR-Bot.md)
 *   LINKS                  KV namespace binding: Discord user -> encrypted GitHub tokens
 *   DISCORD_APPLICATION_ID Discord application id
 *   DISCORD_PUBLIC_KEY     Discord application public key (hex)
 *   GITHUB_CLIENT_ID       GitHub App client id
 *   GITHUB_CLIENT_SECRET   GitHub App client secret              (secret)
 *   SECRET_KEY             32 random bytes, base64               (secret) encrypts tokens, signs /link
 *   GITHUB_REPO            owner/name, e.g. bash-y/CIS_CapstoneProj_Swag01erload
 *   ALLOWED_GUILD_ID       only this Discord server may use the bot
 *   ALLOWED_CHANNEL_ID     optional: only this channel may use the bot
 *   MERGE_METHOD           merge | squash | rebase (default: merge)
 *
 * Single file with no dependencies, so it can be pasted straight into the Cloudflare editor.
 */

// Legal names for every message; GitHub handles are shown only for people not listed here.
const MEMBERS = {
  UiwAntHuynhCIS: "Anthony Huynh",
  "bash-y": "Sebastian Cadena",
  joromanii: "Jomar Rodriguez Canales",
};

const GITHUB_API = "https://api.github.com";
const DISCORD_API = "https://discord.com/api/v10";
const LINK_TTL_MS = 10 * 60 * 1000;
const MAX_CLOCK_SKEW_S = 5 * 60;

// Discord interaction and response types.
const PING = 1, COMMAND = 2, COMPONENT = 3;
const PONG = 1, MESSAGE = 4, DEFER_MESSAGE = 5, DEFER_UPDATE = 6, UPDATE = 7;
const EPHEMERAL = 64;
const ROW = 1, BUTTON = 2, SELECT = 3;
const PRIMARY = 1, SECONDARY = 2, SUCCESS = 3, DANGER = 4, LINK = 5;

const GREEN = 0x2ecc71, PURPLE = 0x8957e5, RED = 0xe74c3c, BLUE = 0x3498db, AMBER = 0xf1c40f, GREY = 0x95a5a6;

const MERGE_STATE = {
  clean: "\u2705 Ready to merge",
  has_hooks: "\u2705 Ready to merge",
  unstable: "\u26A0\uFE0F Mergeable, but some checks are failing",
  blocked: "\u26D4 Blocked: needs an approval from someone other than the author",
  behind: "\u26A0\uFE0F Branch is behind main",
  dirty: "\u274C Merge conflicts: fix them on GitHub first",
  draft: "\u{1F4DD} Draft: press Ready for review, then it can be approved",
  unknown: "\u23F3 GitHub is still working out mergeability; press Refresh",
};

const enc = new TextEncoder();
const dec = new TextDecoder();

// ----------------------------------------------------------------------------- small helpers

const who = (login) => (login ? MEMBERS[login] || `@${login}` : "someone");
const short = (text, n) => {
  const t = (text || "").trim();
  return t.length <= n ? t : t.slice(0, n - 1).trimEnd() + "\u2026";
};
const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
const html = (title, message, status = 200) =>
  new Response(
    `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">` +
      `<title>${esc(title)}</title><body style="font-family:system-ui;max-width:32rem;margin:4rem auto;padding:0 1rem">` +
      `<h1 style="font-size:1.4rem">${esc(title)}</h1><p>${esc(message)}</p></body>`,
    { status, headers: { "content-type": "text/html; charset=utf-8" } },
  );
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

const b64 = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes)));
const unb64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const b64url = (bytes) => b64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const unb64url = (s) => unb64(s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4));

function hexToBytes(hex) {
  if (!/^(?:[0-9a-f]{2})+$/i.test(hex || "")) throw new Error("not hex");
  return Uint8Array.from(hex.match(/../g), (h) => parseInt(h, 16));
}

// Flags are only sent for new ephemeral messages; Discord refuses flag changes on edits.
const message = (content, { ephemeral = false, embeds, components } = {}) => ({
  content,
  embeds,
  components,
  ...(ephemeral ? { flags: EPHEMERAL } : {}),
  allowed_mentions: { parse: [] }, // text from GitHub can never ping @everyone
});
const reply = (content, opts) => ({ type: MESSAGE, data: message(content, opts) });

// ----------------------------------------------------------------------------- crypto

async function importEd25519(raw) {
  try {
    return await crypto.subtle.importKey("raw", raw, { name: "Ed25519" }, false, ["verify"]);
  } catch {
    // Older Workers runtimes only know the non-standard name.
    return await crypto.subtle.importKey("raw", raw, { name: "NODE-ED25519", namedCurve: "NODE-ED25519" }, false, ["verify"]);
  }
}

/** Discord signs timestamp + body with the application's Ed25519 key; anything else is rejected. */
async function verifyDiscord(publicKeyHex, signatureHex, timestamp, body, nowS = Date.now() / 1000) {
  try {
    if (!/^\d+$/.test(timestamp || "") || Math.abs(nowS - Number(timestamp)) > MAX_CLOCK_SKEW_S) return false;
    const key = await importEd25519(hexToBytes(publicKeyHex));
    return await crypto.subtle.verify(key.algorithm, key, hexToBytes(signatureHex), enc.encode(timestamp + body));
  } catch {
    return false;
  }
}

/** Two independent keys derived from SECRET_KEY: AES-GCM for stored tokens, HMAC for /link state. */
async function keys(env) {
  const raw = unb64(env.SECRET_KEY || "");
  if (raw.length < 32) throw new Error("SECRET_KEY must be at least 32 random bytes, base64-encoded");
  const base = await crypto.subtle.importKey("raw", raw, "HKDF", false, ["deriveKey"]);
  const derive = (info, algorithm, usages) =>
    crypto.subtle.deriveKey(
      { name: "HKDF", hash: "SHA-256", salt: new Uint8Array(32), info: enc.encode(info) },
      base, algorithm, false, usages,
    );
  return {
    aes: await derive("swagpc-pr-bot/tokens", { name: "AES-GCM", length: 256 }, ["encrypt", "decrypt"]),
    hmac: await derive("swagpc-pr-bot/link-state", { name: "HMAC", hash: "SHA-256", length: 256 }, ["sign", "verify"]),
  };
}

async function signState(env, discordId) {
  const { hmac } = await keys(env);
  const nonce = b64url(crypto.getRandomValues(new Uint8Array(12)));
  const body = b64url(enc.encode(JSON.stringify({ d: discordId, e: Date.now() + LINK_TTL_MS, n: nonce })));
  const sig = await crypto.subtle.sign("HMAC", hmac, enc.encode(body));
  return `${body}.${b64url(sig)}`;
}

/** Returns the Discord user id the /link button was made for, or null if forged or expired. */
async function verifyState(env, state) {
  try {
    const [body, sig] = (state || "").split(".");
    const { hmac } = await keys(env);
    if (!(await crypto.subtle.verify("HMAC", hmac, unb64url(sig), enc.encode(body)))) return null;
    const data = JSON.parse(dec.decode(unb64url(body)));
    return data.e > Date.now() && typeof data.d === "string" ? data.d : null;
  } catch {
    return null;
  }
}

// Tokens are bound to the Discord user (AES-GCM additional data), so one user's record
// cannot be copied onto another user's key.
async function saveLink(env, discordId, record) {
  const { aes } = await keys(env);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv, additionalData: enc.encode(discordId) }, aes,
    enc.encode(JSON.stringify(record)));
  await env.LINKS.put(`user:${discordId}`, `${b64(iv)}.${b64(ct)}`);
}

async function loadLink(env, discordId) {
  const stored = await env.LINKS.get(`user:${discordId}`);
  if (!stored) return null;
  try {
    const { aes } = await keys(env);
    const [iv, ct] = stored.split(".");
    const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv: unb64(iv), additionalData: enc.encode(discordId) },
      aes, unb64(ct));
    return JSON.parse(dec.decode(pt));
  } catch {
    return null; // wrong key or tampered record: treat as not linked
  }
}

// ----------------------------------------------------------------------------- GitHub

class GitHubError extends Error {
  constructor(status, msg) {
    super(msg);
    this.status = status;
  }
}

async function gh(token, method, path, body) {
  const res = await fetch(`${GITHUB_API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "swagpc-pr-bot",
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) {
    const detail = data?.errors?.map((e) => e.message || e).filter(Boolean).join("; ");
    throw new GitHubError(res.status, [data?.message, detail].filter(Boolean).join(": ") || `HTTP ${res.status}`);
  }
  return data;
}

async function oauthToken(env, params) {
  const res = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json", "User-Agent": "swagpc-pr-bot" },
    body: JSON.stringify({ client_id: env.GITHUB_CLIENT_ID, client_secret: env.GITHUB_CLIENT_SECRET, ...params }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.error || !data.access_token) {
    throw new Error(data.error_description || data.error || "GitHub did not return a token");
  }
  return {
    access_token: data.access_token,
    refresh_token: data.refresh_token || null,
    expires_at: data.expires_in ? Date.now() + data.expires_in * 1000 : null,
  };
}

/** The caller's GitHub token, refreshed when close to expiry. null means "run /link". */
async function userToken(env, discordId) {
  const rec = await loadLink(env, discordId);
  if (!rec) return null;
  if (rec.expires_at && rec.expires_at - 60_000 < Date.now()) {
    if (!rec.refresh_token) return null;
    try {
      Object.assign(rec, await oauthToken(env, { grant_type: "refresh_token", refresh_token: rec.refresh_token }));
      await saveLink(env, discordId, rec);
    } catch {
      await env.LINKS.delete(`user:${discordId}`);
      return null;
    }
  }
  return { token: rec.access_token, login: rec.login };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function prStatus(env, token, number) {
  const base = `/repos/${env.GITHUB_REPO}/pulls/${number}`;
  let pr = await gh(token, "GET", base);
  if (pr.state === "open" && pr.mergeable === null) {
    await sleep(1500); // GitHub computes mergeability lazily after the first read
    pr = await gh(token, "GET", base);
  }
  const reviews = await gh(token, "GET", `${base}/reviews?per_page=100`);
  const latest = {};
  for (const r of reviews) {
    if (["APPROVED", "CHANGES_REQUESTED", "DISMISSED"].includes(r.state)) latest[r.user?.login] = r.state;
  }
  const approvers = Object.keys(latest).filter((l) => latest[l] === "APPROVED");
  const changesBy = Object.keys(latest).filter((l) => latest[l] === "CHANGES_REQUESTED");
  let checks = null;
  try {
    const runs = await gh(token, "GET", `/repos/${env.GITHUB_REPO}/commits/${pr.head.sha}/check-runs?per_page=100`);
    checks = { passed: 0, failed: 0, pending: 0 };
    for (const run of runs.check_runs || []) {
      if (run.status !== "completed") checks.pending++;
      else if (["success", "neutral", "skipped"].includes(run.conclusion)) checks.passed++;
      else checks.failed++;
    }
  } catch {
    // Check runs need the app's "Checks: read" permission; the card just omits them without it.
  }
  return { pr, approvers, changesBy, checks };
}

// ----------------------------------------------------------------------------- cards

function card({ pr, approvers, changesBy, checks }) {
  const n = pr.number, sha = pr.head.sha;
  const merged = Boolean(pr.merged_at), closed = pr.state !== "open";
  const state = merged ? "\u{1F7E3} Merged" : closed ? "\u26AA Closed" : pr.draft ? "\u{1F4DD} Draft" : "\u{1F7E2} Open";
  const reviews = changesBy.length
    ? `\u{1F6D1} Changes requested by ${changesBy.map(who).join(", ")}`
    : approvers.length ? `\u2705 Approved by ${approvers.map(who).join(", ")}` : "\u23F3 No approval yet";
  const fields = [
    { name: "Author", value: who(pr.user?.login), inline: true },
    { name: "Branch", value: `\`${pr.head.ref}\` \u2192 \`${pr.base.ref}\``, inline: true },
    { name: "Status", value: state, inline: true },
    { name: "Reviews", value: reviews, inline: false },
  ];
  if (checks) {
    const parts = [];
    if (checks.failed) parts.push(`\u274C ${checks.failed} failed`);
    if (checks.pending) parts.push(`\u23F3 ${checks.pending} running`);
    if (checks.passed) parts.push(`\u2705 ${checks.passed} passed`);
    fields.push({ name: "Checks", value: parts.join(" \u00B7 ") || "No checks", inline: true });
  }
  if (!closed) {
    fields.push({ name: "Merge", value: MERGE_STATE[pr.mergeable_state] || `\u2139\uFE0F ${pr.mergeable_state}`, inline: true });
  } else if (merged) {
    fields.push({ name: "Merged by", value: who(pr.merged_by?.login), inline: true });
  }
  const color = merged ? PURPLE : closed ? GREY : changesBy.length ? RED : approvers.length ? GREEN : AMBER;
  const buttons = [];
  if (!closed && pr.draft) {
    // GitHub won't merge a draft, so the first step is marking it ready; then Approve appears.
    buttons.push(
      { type: BUTTON, style: PRIMARY, label: "Ready for review", emoji: { name: "\u{1F440}" }, custom_id: `ready:${n}:${sha}` },
      { type: BUTTON, style: SECONDARY, label: "Refresh", emoji: { name: "\u{1F504}" }, custom_id: `refresh:${n}` },
    );
  } else if (!closed) {
    buttons.push(
      { type: BUTTON, style: SUCCESS, label: "Approve", emoji: { name: "\u2705" }, custom_id: `approve:${n}:${sha}` },
      { type: BUTTON, style: PRIMARY, label: "Merge", emoji: { name: "\u{1F500}" }, custom_id: `merge:${n}:${sha}` },
      { type: BUTTON, style: SECONDARY, label: "Refresh", emoji: { name: "\u{1F504}" }, custom_id: `refresh:${n}` },
    );
  }
  buttons.push({ type: BUTTON, style: LINK, label: "Review changes", url: `${pr.html_url}/files` });
  return message("", {
    embeds: [{
      title: short(`PR #${n}: ${pr.title}`, 256),
      url: pr.html_url,
      color,
      description: short(pr.body, 300) || undefined,
      fields,
      footer: { text: `Head commit ${sha.slice(0, 7)} \u00B7 approvals apply to this exact commit` },
    }],
    components: [{ type: ROW, components: buttons }],
  });
}

// ----------------------------------------------------------------------------- Discord follow-ups

async function discord(env, method, path, body, retry = true) {
  const res = await fetch(`${DISCORD_API}${path}`, {
    method,
    headers: { "Content-Type": "application/json", "User-Agent": "DiscordBot (swagpc-pr-bot, 1.0)" },
    body: JSON.stringify(body),
  });
  if (res.ok) return;
  const detail = short(await res.text().catch(() => ""), 300);
  // Log without the interaction token, which is a credential for 15 minutes.
  console.log(`Discord ${method} ${path.split("/").slice(0, 3).join("/")}/\u2026 -> ${res.status} ${detail}`);
  // If Discord rejects a rich reply, replace it with plain text so nobody is left
  // looking at "thinking..." forever.
  if (retry && res.status === 400 && (body.embeds || body.components)) {
    await discord(env, method, path, message(`\u26a0\ufe0f Discord rejected the bot's reply (HTTP 400). ` +
      "Ask the bot owner to check the Worker logs.", { embeds: [], components: [] }), false);
  }
}
const editOriginal = (env, i, body) =>
  discord(env, "PATCH", `/webhooks/${env.DISCORD_APPLICATION_ID}/${i.token}/messages/@original`, body);
const followUp = (env, i, body) => discord(env, "POST", `/webhooks/${env.DISCORD_APPLICATION_ID}/${i.token}`, body);

/** Answer within Discord's 3-second limit, then finish the GitHub work in the background. */
function later(ctx, env, i, type, work) {
  ctx.waitUntil(
    work().catch((err) => {
      const text = err instanceof GitHubError ? `GitHub said: ${err.message}` : `Something went wrong: ${err.message}`;
      return type === DEFER_UPDATE
        ? followUp(env, i, message(`\u26A0\uFE0F ${short(text, 1800)}`, { ephemeral: true }))
        : editOriginal(env, i, message(`\u26A0\uFE0F ${short(text, 1800)}`));
    }),
  );
  return { type };
}

const NOT_LINKED = reply("Link your GitHub account first with `/link`, so GitHub records you as the reviewer.",
  { ephemeral: true });

// ----------------------------------------------------------------------------- commands

async function onCommand(i, env, ctx, origin, userId) {
  const name = i.data?.name;

  if (name === "link") {
    const url = new URL("https://github.com/login/oauth/authorize");
    url.searchParams.set("client_id", env.GITHUB_CLIENT_ID);
    url.searchParams.set("redirect_uri", `${origin}/github/callback`);
    url.searchParams.set("state", await signState(env, userId));
    return reply("Sign in with GitHub to link your account. This button works for 10 minutes and only for you.", {
      ephemeral: true,
      components: [{ type: ROW, components: [{ type: BUTTON, style: LINK, label: "Link GitHub account", url: url.toString() }] }],
    });
  }

  if (name === "unlink") {
    await env.LINKS.delete(`user:${userId}`);
    return reply("Unlinked. To revoke the bot's access completely, remove **SwagPc PR Bot** under GitHub \u2192 Settings \u2192 Applications \u2192 Authorized GitHub Apps.",
      { ephemeral: true });
  }

  if (name === "whoami") {
    const rec = await loadLink(env, userId);
    return reply(rec ? `You're linked as **${who(rec.login)}** (GitHub @${rec.login}).` : "You haven't linked a GitHub account. Use `/link`.",
      { ephemeral: true });
  }

  const auth = await userToken(env, userId);
  if (!auth) return NOT_LINKED;

  if (name === "pr") {
    const number = Number(i.data.options?.find((o) => o.name === "number")?.value);
    if (!Number.isInteger(number) || number < 1) return reply("Give a pull request number, e.g. `/pr 91`.", { ephemeral: true });
    return later(ctx, env, i, DEFER_MESSAGE, async () => editOriginal(env, i, card(await prStatus(env, auth.token, number))));
  }

  if (name === "prs") {
    return later(ctx, env, i, DEFER_MESSAGE, async () => {
      const prs = await gh(auth.token, "GET", `/repos/${env.GITHUB_REPO}/pulls?state=open&sort=created&direction=asc&per_page=25`);
      if (!prs.length) return editOriginal(env, i, message("No open pull requests. \u{1F389}"));
      const lines = prs.map((p) => `[#${p.number}](${p.html_url}) ${short(p.title, 70)} \u2014 ${who(p.user?.login)}${p.draft ? " \u00B7 \u{1F4DD} draft" : ""}`);
      return editOriginal(env, i, message("", {
        embeds: [{ title: `\u{1F500} Open pull requests (${prs.length})`, color: BLUE, description: short(lines.join("\n"), 4000),
          footer: { text: "Pick one below to approve or merge it" } }],
        components: [{ type: ROW, components: [{
          type: SELECT, custom_id: "pick", placeholder: "Choose a pull request\u2026",
          options: prs.map((p) => ({ label: short(`#${p.number} ${p.title}`, 100), value: String(p.number),
            description: short(who(p.user?.login), 100) })),
        }] }],
      }));
    });
  }

  return reply("Unknown command.", { ephemeral: true });
}

// ----------------------------------------------------------------------------- buttons

const COMPONENT_ID = /^(approve|merge|confirm|ready|refresh|cancel|pick):?(\d{1,7})?(?::([0-9a-f]{40}))?$/;

async function onComponent(i, env, ctx, userId) {
  const id = i.data?.custom_id === "pick" ? `pick:${i.data.values?.[0]}` : i.data?.custom_id;
  const m = COMPONENT_ID.exec(id || "");
  if (!m) return reply("That button is out of date.", { ephemeral: true });
  const [, action, num, sha] = m;
  const number = Number(num);

  if (action === "cancel") return { type: UPDATE, data: message("Merge cancelled.", { components: [] }) };
  if (!number || (["approve", "merge", "confirm", "ready"].includes(action) && !sha)) {
    return reply("That button is out of date.", { ephemeral: true });
  }

  const auth = await userToken(env, userId);
  if (!auth) return NOT_LINKED;
  const repo = env.GITHUB_REPO;

  if (action === "pick") {
    return later(ctx, env, i, DEFER_MESSAGE, async () => editOriginal(env, i, card(await prStatus(env, auth.token, number))));
  }

  if (action === "refresh") {
    return later(ctx, env, i, DEFER_UPDATE, async () => editOriginal(env, i, card(await prStatus(env, auth.token, number))));
  }

  if (action === "approve") {
    return later(ctx, env, i, DEFER_UPDATE, async () => {
      const st = await prStatus(env, auth.token, number);
      if (st.pr.head.sha !== sha) {
        await editOriginal(env, i, card(st));
        return followUp(env, i, message(`PR #${number} has new commits since this card was posted. ` +
          "Review the new changes, then press Approve on the refreshed card.", { ephemeral: true }));
      }
      await gh(auth.token, "POST", `/repos/${repo}/pulls/${number}/reviews`,
        { event: "APPROVE", commit_id: sha, body: "Approved from Discord with SwagPc PR Bot." });
      return editOriginal(env, i, card(await prStatus(env, auth.token, number)));
    });
  }

  if (action === "ready") {
    return later(ctx, env, i, DEFER_UPDATE, async () => {
      const st = await prStatus(env, auth.token, number);
      if (st.pr.draft) {
        // REST has no endpoint for this; GraphQL does, and runs as the clicking user.
        const res = await gh(auth.token, "POST", "/graphql", {
          query: "mutation($id: ID!) { markPullRequestReadyForReview(input: { pullRequestId: $id }) { pullRequest { isDraft } } }",
          variables: { id: st.pr.node_id },
        });
        if (res?.errors?.length) throw new GitHubError(422, res.errors.map((e) => e.message).join("; "));
      }
      return editOriginal(env, i, card(await prStatus(env, auth.token, number)));
    });
  }

  if (action === "merge") {
    const method = env.MERGE_METHOD || "merge";
    return reply(`Merge **PR #${number}** into its base branch as a **${method}** commit? ` +
      `It will merge commit \`${sha.slice(0, 7)}\` only; if anyone pushed since, the merge is refused.`, {
      ephemeral: true,
      components: [{ type: ROW, components: [
        { type: BUTTON, style: DANGER, label: "Confirm merge", custom_id: `confirm:${number}:${sha}` },
        { type: BUTTON, style: SECONDARY, label: "Cancel", custom_id: "cancel" },
      ] }],
    });
  }

  if (action === "confirm") {
    return later(ctx, env, i, DEFER_UPDATE, async () => {
      const result = await gh(auth.token, "PUT", `/repos/${repo}/pulls/${number}/merge`,
        { sha, merge_method: env.MERGE_METHOD || "merge" });
      await editOriginal(env, i, message(`\u{1F7E3} Merged PR #${number} (\`${(result?.sha || "").slice(0, 7)}\`).`, { components: [] }));
      return followUp(env, i, message(`\u{1F7E3} **PR #${number}** was merged by **${who(auth.login)}** from Discord.`));
    });
  }

  return reply("That button is out of date.", { ephemeral: true });
}

// ----------------------------------------------------------------------------- routes

async function interactions(request, env, ctx) {
  const body = await request.text();
  const ok = await verifyDiscord(env.DISCORD_PUBLIC_KEY, request.headers.get("X-Signature-Ed25519"),
    request.headers.get("X-Signature-Timestamp"), body);
  if (!ok) return new Response("invalid request signature", { status: 401 });

  const i = JSON.parse(body);
  if (i.type === PING) return json({ type: PONG });
  if (env.ALLOWED_GUILD_ID && i.guild_id !== env.ALLOWED_GUILD_ID) {
    return json(reply("This bot only works in the SwagPc team server.", { ephemeral: true }));
  }
  if (env.ALLOWED_CHANNEL_ID && (i.channel_id || i.channel?.id) !== env.ALLOWED_CHANNEL_ID) {
    return json(reply(`This bot only works in <#${env.ALLOWED_CHANNEL_ID}>.`, { ephemeral: true }));
  }
  const userId = (i.member?.user || i.user)?.id;
  const origin = new URL(request.url).origin;
  if (i.type === COMMAND) return json(await onCommand(i, env, ctx, origin, userId));
  if (i.type === COMPONENT) return json(await onComponent(i, env, ctx, userId));
  return json(reply("Unsupported interaction.", { ephemeral: true }));
}

async function githubCallback(request, env) {
  const url = new URL(request.url);
  const discordId = await verifyState(env, url.searchParams.get("state"));
  if (!discordId) return html("Link expired", "Run /link in Discord again and use the new button within 10 minutes.", 400);
  const code = url.searchParams.get("code");
  if (!code) return html("Not linked", "GitHub sign-in was cancelled. Run /link in Discord to try again.", 400);

  let tokens;
  try {
    tokens = await oauthToken(env, { code, redirect_uri: `${url.origin}/github/callback` });
  } catch (err) {
    return html("Not linked", `GitHub sign-in failed: ${err.message}. Run /link in Discord to try again.`, 400);
  }
  const user = await gh(tokens.access_token, "GET", "/user");
  let repo;
  try {
    repo = await gh(tokens.access_token, "GET", `/repos/${env.GITHUB_REPO}`);
  } catch {
    return html("Not linked", `@${user.login} can't reach ${env.GITHUB_REPO} through the bot. ` +
      "Ask the repo owner to install the SwagPc PR Bot GitHub App on it, and check you're a collaborator.", 403);
  }
  await saveLink(env, discordId, { login: user.login, ...tokens });
  const note = repo.permissions?.push ? "" : " Your account has read-only access, so Approve and Merge will be refused.";
  return html("GitHub account linked", `Linked as ${who(user.login)} (@${user.login}). You can close this tab and go back to Discord.${note}`);
}

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);
    try {
      if (request.method === "POST" && pathname === "/interactions") return await interactions(request, env, ctx);
      if (request.method === "GET" && pathname === "/github/callback") return await githubCallback(request, env);
      if (request.method === "GET" && pathname === "/") return new Response("SwagPc PR Bot is running.");
      return new Response("Not found", { status: 404 });
    } catch (err) {
      console.log(`Unhandled error: ${err.message}`);
      return new Response("Internal error", { status: 500 });
    }
  },
};
