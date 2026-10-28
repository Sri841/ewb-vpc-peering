const $ = (id) => document.getElementById(id);
const show = (el, obj) => (el.textContent = typeof obj === "string" ? obj : JSON.stringify(obj, null, 2));

async function getJSON(url, opts) {
  const r = await fetch(url, opts);
  let body = null;
  try { body = await r.json(); } catch (_) {}
  return { ok: r.ok, status: r.status, body };
}

async function refresh() {
  const a = await getJSON("/api/info");
  show($("card-a").querySelector("pre"), a.body || "App-A API error");

  const p = await getJSON("/api/peer");
  const badge = $("link-badge");
  if (p.body && p.body.reachable) {
    badge.textContent = "UP"; badge.className = "badge ok";
    show($("link-body"), { reachable: true, latency_ms: p.body.latency_ms, note: "App-B saw the request from " + p.body.app_b.seen_client_ip });
    show($("card-b").querySelector("pre"), p.body.app_b);
  } else {
    badge.textContent = "DOWN"; badge.className = "badge bad";
    show($("link-body"), { reachable: false, latency_ms: p.body && p.body.latency_ms, error: p.body && p.body.error });
    show($("card-b").querySelector("pre"), "App-B not reachable over peering.\nCheck: peering Active, routes on BOTH sides, SG tcp/9000 from 10.10.2.10/32.");
  }
  await loadNotes();
}

async function loadNotes() {
  const n = await getJSON("/api/notes");
  const list = $("notes");
  list.replaceChildren();
  if (!n.ok) { $("note-error").hidden = false; $("note-error").textContent = "Cannot load notes: " + ((n.body && n.body.error) || n.status); return; }
  $("note-error").hidden = true;
  [...n.body].reverse().forEach((note) => {
    const li = document.createElement("li");
    const t = document.createElement("div"); t.textContent = note.text;
    const m = document.createElement("div"); m.className = "meta";
    m.textContent = `${note.author} · ${note.ts} · stored by App-B (request from ${note.from_ip})`;
    li.append(t, m); list.append(li);
  });
  if (!n.body.length) { const li = document.createElement("li"); li.textContent = "No notes yet."; list.append(li); }
}

$("btn-ping").onclick = async () => {
  show($("ping-out"), "pinging…");
  const r = await getJSON("/api/ping");
  const b = r.body || {};
  show($("ping-out"), b.error ? b.error : `${b.received}/${b.transmitted} replies, ${b.loss_pct}% loss\n` + (b.raw || []).join("\n"));
};
$("btn-refresh").onclick = refresh;
$("note-form").onsubmit = async (e) => {
  e.preventDefault();
  const res = await getJSON("/api/notes", { method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ author: $("author").value, text: $("text").value }) });
  if (!res.ok) { $("note-error").hidden = false; $("note-error").textContent = "Post failed: " + ((res.body && res.body.error) || res.status); return; }
  $("text").value = ""; loadNotes();
};
refresh(); setInterval(refresh, 15000);
