// /admin：Yang 管邀请码的网页。生成码、看用了几次、停用、清掉绑定的手机、拨「必须有邀请码」的开关。
// 网页本身谁都能打开，里面的数据和操作都要管理密码（Worker 密钥 ADMIN_TOKEN）。
// 第一次用：打开 /admin#token=<管理密码>，密码存进这个浏览器，地址栏里的会马上抹掉。

export const ADMIN_HTML = `<!doctype html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>拍照算番 · 邀请码</title>
<style>
  :root { color-scheme: light; --ink: #16150F; --gray: #6E6C64; --faint: #A9A69C; --line: #E7E4DC;
    --paper: #F7F6F2; --card: #FFFFFF; --red: #C23B22; }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--paper); color: var(--ink);
    font: 16px/1.6 -apple-system, "PingFang SC", "Noto Sans SC", sans-serif; }
  main { max-width: 560px; margin: 0 auto; padding: 48px 20px 80px; }
  .seal { display: inline-block; width: 10px; height: 10px; background: var(--red); border-radius: 2px; }
  h1 { font: 600 28px/1.3 "Songti SC", "Noto Serif SC", serif; margin: 14px 0 32px; letter-spacing: .04em; }
  h2 { font-size: 13px; font-weight: 500; color: var(--gray); margin: 36px 0 10px; letter-spacing: .08em; }
  .card { background: var(--card); border-radius: 18px; padding: 18px 18px; }
  input { width: 100%; font: inherit; padding: 12px 14px; border: 1px solid var(--line); border-radius: 12px;
    background: var(--card); color: var(--ink); outline: none; }
  input:focus { border-color: var(--ink); }
  .row { display: flex; gap: 10px; }
  .row > * { flex: 1; }
  label { font-size: 13px; color: var(--gray); display: block; margin: 0 0 4px; }
  button { font: inherit; cursor: pointer; border: 0; background: none; color: var(--ink); padding: 0; }
  .primary { width: 100%; background: var(--ink); color: #fff; border-radius: 14px; padding: 14px; font-weight: 600; margin-top: 14px; }
  .link { color: var(--gray); font-size: 14px; }
  .link.red { color: var(--red); }
  .muted { color: var(--gray); font-size: 14px; }
  .faint { color: var(--faint); font-size: 13px; }
  .code { font: 600 26px/1.2 ui-monospace, "SF Mono", Menlo, monospace; letter-spacing: .18em; }
  .new { text-align: center; padding: 22px 18px; margin-top: 14px; }
  .new .code { font-size: 34px; color: var(--red); }
  .item { padding: 16px 0; border-top: 1px solid var(--line); }
  .item:first-child { border-top: 0; padding-top: 2px; }
  .item.off .code, .item.off .note { color: var(--faint); text-decoration: line-through; }
  .head { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; }
  .note { font-size: 15px; }
  .actions { display: flex; gap: 18px; margin-top: 8px; }
  .switch { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
  .switch button { white-space: nowrap; flex: none; }
  .err { color: var(--red); font-size: 14px; min-height: 1.6em; margin-top: 8px; }
  details summary { cursor: pointer; color: var(--gray); font-size: 14px; margin-top: 12px; }
  .hidden { display: none; }
</style>
</head>
<body>
<main>
<span class="seal"></span>
<h1>邀请码</h1>

<section id="login" class="hidden">
  <div class="card">
    <label for="token">管理密码</label>
    <input id="token" type="password" autocomplete="current-password">
    <button class="primary" id="enter">进入</button>
  </div>
</section>

<section id="app" class="hidden">
  <div class="card switch">
    <div>
      <div id="reqTitle"></div>
      <div class="faint" id="reqHint"></div>
    </div>
    <button class="link red" id="reqToggle"></button>
  </div>

  <h2>新的邀请码</h2>
  <div class="card">
    <label for="note">给谁</label>
    <input id="note" maxlength="40" placeholder="比如 老张、审核专用">
    <details>
      <summary>次数和手机数</summary>
      <div class="row" style="margin-top:10px">
        <div><label for="devices">最多几台手机</label><input id="devices" inputmode="numeric"></div>
        <div><label for="daily">每天最多几次</label><input id="daily" inputmode="numeric"></div>
      </div>
    </details>
    <button class="primary" id="create">生成邀请码</button>
    <div id="fresh" class="new hidden">
      <div class="code" id="freshCode"></div>
      <div class="muted" id="freshNote"></div>
      <div class="actions" style="justify-content:center"><button class="link red" id="freshCopy">复制</button></div>
    </div>
  </div>

  <h2 id="listTitle">发出去的</h2>
  <div class="card" id="list"></div>
</section>

<div class="err" id="err"></div>
</main>

<script>
(() => {
  const KEY = "majiang-admin-token";
  const $ = (id) => document.getElementById(id);
  let token = "";
  let state = null;

  const hash = new URLSearchParams(location.hash.slice(1));
  if (hash.get("token")) {
    localStorage.setItem(KEY, hash.get("token"));
    history.replaceState(null, "", location.pathname);
  }
  token = localStorage.getItem(KEY) || "";

  function el(tag, attrs = {}, ...children) {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (k === "onclick") node.onclick = v; else node.setAttribute(k, v);
    }
    for (const c of children) if (c != null) node.append(c);
    return node;
  }

  function showError(message) { $("err").textContent = message || ""; }

  async function api(path, body) {
    showError("");
    const res = await fetch("/admin/api/" + path, {
      method: body ? "POST" : "GET",
      headers: { "Authorization": "Bearer " + token, "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
    });
    const data = await res.json().catch(() => ({}));
    if (res.status === 401) { localStorage.removeItem(KEY); token = ""; show(); }
    if (!res.ok) throw new Error(data?.error?.message || ("出错了（" + res.status + "）"));
    return data;
  }

  function when(iso) {
    if (!iso) return "还没用过";
    const d = new Date(iso);
    const pad = (n) => String(n).padStart(2, "0");
    return "最近 " + (d.getMonth() + 1) + "月" + d.getDate() + "日 " + pad(d.getHours()) + ":" + pad(d.getMinutes());
  }

  async function copy(code) {
    try { await navigator.clipboard.writeText(code); showError(""); }
    catch { showError("没复制上，长按码手动复制"); }
  }

  function render() {
    $("reqTitle").textContent = state.inviteRequired ? "现在：必须有邀请码" : "现在：没码也能用 AI 认牌";
    $("reqHint").textContent = state.inviteRequired
      ? "没码的人只能用离线认牌和手动选牌"
      : "过渡期：带输入框的新版 App 发出去以后再改成要码";
    $("reqToggle").textContent = state.inviteRequired ? "放开" : "改成要码";
    $("devices").placeholder = String(state.defaults.deviceLimit);
    $("daily").placeholder = String(state.defaults.dailyLimit);

    const list = $("list");
    list.replaceChildren();
    $("listTitle").textContent = state.codes.length ? "发出去的 · " + state.codes.length : "发出去的";
    if (!state.codes.length) list.append(el("div", { class: "muted" }, "还没有邀请码"));
    for (const c of state.codes) {
      const meta = "手机 " + c.devices + "/" + c.deviceLimit + " · 今天 " + c.today + "/" + c.dailyLimit
        + " · 共 " + c.uses + " 次 · " + when(c.lastUsed);
      const actions = el("div", { class: "actions" },
        el("button", { class: "link", onclick: () => copy(c.code) }, "复制"),
        el("button", { class: "link" + (c.disabled ? "" : " red"), onclick: () => act(c, c.disabled ? "enable" : "disable") },
          c.disabled ? "重新启用" : "停用"),
        c.devices ? el("button", { class: "link", onclick: () => act(c, "unbind") }, "清掉绑定的手机") : null);
      list.append(el("div", { class: "item" + (c.disabled ? " off" : "") },
        el("div", { class: "head" }, el("span", { class: "code" }, c.code), el("span", { class: "note" }, c.note || "")),
        el("div", { class: "faint" }, c.disabled ? "已停用 · " + meta : meta),
        actions));
    }
  }

  async function act(c, action) {
    const ask = {
      disable: "停用 " + c.code + "？用这个码的手机马上就不能用 AI 认牌了。",
      unbind: "清掉 " + c.code + " 绑定的手机？之后最先用它的 " + c.deviceLimit + " 台手机会重新绑上。",
    }[action];
    if (ask && !confirm(ask)) return;
    try { await api("codes/" + c.code, { action }); await load(); } catch (e) { showError(e.message); }
  }

  async function load() {
    try { state = await api("codes"); render(); } catch (e) { showError(e.message); }
  }

  function show() {
    $("login").classList.toggle("hidden", !!token);
    $("app").classList.toggle("hidden", !token);
    if (token) load();
  }

  $("enter").onclick = () => {
    token = $("token").value.trim();
    if (token) localStorage.setItem(KEY, token);
    show();
  };
  $("token").onkeydown = (e) => { if (e.key === "Enter") $("enter").click(); };

  $("reqToggle").onclick = async () => {
    const next = !state.inviteRequired;
    if (next && !confirm("改成要码以后，没有邀请码的手机（包括还没更新的旧版 App）都用不了 AI 认牌。确定？")) return;
    try { state = await api("settings", { inviteRequired: next }); render(); } catch (e) { showError(e.message); }
  };

  $("create").onclick = async () => {
    try {
      const c = await api("codes", { note: $("note").value, deviceLimit: $("devices").value, dailyLimit: $("daily").value });
      $("freshCode").textContent = c.code;
      $("freshNote").textContent = c.note || "";
      $("freshCopy").onclick = () => copy(c.code);
      $("fresh").classList.remove("hidden");
      $("note").value = ""; $("devices").value = ""; $("daily").value = "";
      await load();
    } catch (e) { showError(e.message); }
  };

  show();
})();
</script>
</body>
</html>
`;
