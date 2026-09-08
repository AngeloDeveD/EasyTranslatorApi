const TOKEN_KEY = "easytranslator.jwt";
let token = localStorage.getItem(TOKEN_KEY) || "";
let chatSocket = null;

const $ = (id) => document.getElementById(id);
const val = (id) => ($(id)?.value || "").trim();

function setValue(id, value) {
  const el = $(id);
  if (el) el.value = value ?? "";
}

function formatJson(data) {
  if (typeof data === "string") return data;
  return JSON.stringify(data, null, 2);
}

function shortToken(value) {
  if (!value) return "No token";
  if (value.length <= 24) return value;
  return `${value.slice(0, 12)}...${value.slice(-10)}`;
}

function setToken(nextToken) {
  token = nextToken || "";
  if (token) {
    localStorage.setItem(TOKEN_KEY, token);
  } else {
    localStorage.removeItem(TOKEN_KEY);
  }
  updateAuthStatus();
}

function updateAuthStatus() {
  const auth = $("authStatus");
  const preview = $("tokenPreview");
  auth.textContent = token ? "token: set" : "token: empty";
  auth.className = `pill ${token ? "on" : "off"}`;
  preview.textContent = shortToken(token);
}

function setServerStatus(kind, text) {
  const el = $("serverStatus");
  el.textContent = text;
  el.className = `pill ${kind}`;
}

function statusClass(status) {
  if (status >= 200 && status < 300) return "status-ok";
  if (status >= 400) return "status-error";
  return "status-warn";
}

function log(title, data, status) {
  const box = $("log");
  const time = new Date().toLocaleTimeString("ru-RU");
  const statusText = typeof status === "number" ? ` ${status}` : "";
  const entry = `[${time}]${statusText} ${title}\n${formatJson(data)}\n\n`;
  box.textContent = entry + box.textContent;
}

async function parseResponse(res) {
  if (res.status === 204) return "";
  const type = res.headers.get("content-type") || "";
  if (type.includes("application/json")) {
    try {
      return await res.json();
    } catch (error) {
      return { error: "JSON parse failed", detail: String(error) };
    }
  }
  return await res.text();
}

async function apiFetch(method, path, body) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;

  const options = { method, headers };
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    options.body = typeof body === "string" ? body : JSON.stringify(body);
  }

  const res = await fetch(path, options);
  const data = await parseResponse(res);
  log(`${method} ${path}`, data, res.status);
  return { status: res.status, data, ok: res.ok };
}

async function apiUpload(method, path, formData) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(path, { method, headers, body: formData });
  const data = await parseResponse(res);
  log(`${method} ${path}`, data, res.status);
  return { status: res.status, data, ok: res.ok };
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function renderObject(targetId, data) {
  const target = $(targetId);
  target.className = "data-view";
  target.innerHTML = `<pre class="object-view">${escapeHtml(formatJson(data))}</pre>`;
}

function renderEmpty(targetId, text) {
  const target = $(targetId);
  target.className = "data-view empty";
  target.textContent = text;
}

function setGameIdEverywhere(id) {
  ["game_id", "del_gameId", "tr_gameId"].forEach((field) => setValue(field, id));
}

function table(headers, rows) {
  const head = headers.map((item) => `<th>${escapeHtml(item)}</th>`).join("");
  const body = rows.map((row) => `<tr>${row.map((cell) => `<td>${cell}</td>`).join("")}</tr>`).join("");
  return `<table class="data-table"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
}

function renderGames(data) {
  if (!Array.isArray(data)) {
    renderObject("gamesView", data);
    return;
  }
  if (data.length === 0) {
    renderEmpty("gamesView", "Games list is empty");
    return;
  }

  const rows = data.map((game) => {
    const translations = Array.isArray(game.translations)
      ? game.translations.length
      : Array.isArray(game.translateCards)
        ? game.translateCards.length
        : 0;
    return [
      escapeHtml(game.id),
      escapeHtml(game.title),
      escapeHtml(game.steamAppId || ""),
      escapeHtml(game.steamDeckCommand || ""),
      escapeHtml(translations),
      `<button class="btn ghost small" data-select-game="${escapeHtml(game.id)}" type="button">Use</button>`,
    ];
  });

  $("gamesView").className = "data-view";
  $("gamesView").innerHTML = table(["ID", "Title", "Steam", "Deck command", "Translations", ""], rows);
}

function renderCards(data) {
  if (!Array.isArray(data)) {
    renderObject("gamesView", data);
    return;
  }
  if (data.length === 0) {
    renderEmpty("gamesView", "Cards list is empty");
    return;
  }

  const rows = data.map((card) => [
    escapeHtml(card.id),
    escapeHtml(card.title),
    escapeHtml(card.gameId),
    escapeHtml(card.iconUrl),
    `<button class="btn ghost small" data-select-game="${escapeHtml(card.gameId)}" type="button">Use</button>`,
  ]);

  $("gamesView").className = "data-view";
  $("gamesView").innerHTML = table(["Card ID", "Title", "Game ID", "Icon", ""], rows);
}

function renderUsers(data) {
  const users = Array.isArray(data) ? data : data?.data;
  if (!Array.isArray(users)) {
    renderObject("usersView", data);
    return;
  }
  if (users.length === 0) {
    renderEmpty("usersView", "Users list is empty");
    return;
  }

  const rows = users.map((user) => [
    escapeHtml(user.id ?? user.ID),
    escapeHtml(user.nickname ?? user.Nickname),
    escapeHtml(user.role ?? user.Role),
    escapeHtml(user.isBlocked ?? user.IsBlocked ?? false),
    escapeHtml(user.warnCount ?? user.WarnCount ?? 0),
  ]);

  $("usersView").className = "data-view";
  $("usersView").innerHTML = table(["ID", "Nickname", "Role", "Blocked", "Warns"], rows);
}

function appendChat(line) {
  const box = $("chatBox");
  const time = new Date().toLocaleTimeString("ru-RU");
  box.textContent = `[${time}] ${line}\n` + box.textContent;
}

function setChatStatus(connected, text) {
  const el = $("chatStatus");
  el.textContent = text;
  el.className = `pill ${connected ? "on" : "off"}`;
}

const actions = {
  async health() {
    const result = await apiFetch("GET", "/health");
    setServerStatus(result.ok ? "on" : "warn", result.ok ? "server: online" : `server: ${result.status}`);
  },

  async register() {
    await apiFetch("POST", "/api/auth/register", {
      firstName: val("reg_firstName"),
      lastName: val("reg_lastName"),
      nickname: val("reg_nickname"),
      password: val("reg_password"),
    });
  },

  async login() {
    const result = await apiFetch("POST", "/api/auth/login", {
      nickname: val("login_nickname"),
      password: val("login_password"),
    });
    if (result.data?.token) setToken(result.data.token);
  },

  async me() {
    await apiFetch("GET", "/api/auth/me");
  },

  async steamLookup() {
    const query = val("steam_query");
    if (!query) {
      log("Steam lookup", { error: "Title is empty" });
      return;
    }

    const result = await apiFetch("GET", `/games/gsgi/${encodeURIComponent(query)}`);
    const strip = $("steamResult");
    if (result.ok && result.data?.id) {
      setValue("add_title", result.data.title);
      setValue("add_steamAppId", result.data.id);
      strip.className = "result-strip ok";
      strip.textContent = `${result.data.title} / Steam AppID ${result.data.id}`;
    } else {
      strip.className = "result-strip warn";
      strip.textContent = "Steam lookup did not return a game";
    }
  },

  async getCards() {
    const result = await apiFetch("GET", "/cards");
    renderCards(result.data);
  },

  async getGames() {
    const result = await apiFetch("GET", "/games");
    renderGames(result.data);
  },

  async getGameById() {
    const result = await apiFetch("GET", `/games/${val("game_id")}`);
    renderObject("gameView", result.data);
  },

  async addGame() {
    const fd = new FormData();
    fd.append("Title", val("add_title"));

    const steamAppId = val("add_steamAppId");
    if (steamAppId) fd.append("steamAppId", steamAppId);

    const deckCommand = val("add_steamDeckCommand");
    if (deckCommand) fd.append("steamDeckCommand", deckCommand);

    const big = $("add_bigPic").files[0];
    const small = $("add_smallPic").files[0];
    if (big) fd.append("big_pic", big);
    if (small) fd.append("small_pic", small);

    const result = await apiUpload("POST", "/games/add", fd);
    if (result.status === 409 && result.data?.status === "alreadycreated") {
      setGameIdEverywhere(result.data.gameId || result.data.id);
      $("steamResult").className = "result-strip warn";
      $("steamResult").textContent = `Already created: ${result.data.title} / gameId ${result.data.gameId || result.data.id}`;
    } else if (result.ok && result.data?.gameId) {
      setGameIdEverywhere(result.data.gameId);
      await actions.getGames();
    }
  },

  async deleteGame() {
    await apiFetch("DELETE", `/games/${val("del_gameId")}`);
  },

  async translate() {
    const file = $("tr_file").files[0];
    if (!file) {
      log("Upload translation", { error: "Archive file is empty" });
      return;
    }

    const fd = new FormData();
    fd.append("file", file);
    fd.append("authorName", val("tr_authorName"));
    fd.append("source", val("tr_source"));
    fd.append("version", val("tr_version"));
    fd.append("percentReady", val("tr_percentReady"));
    await apiUpload("POST", `/games/translate/${val("tr_gameId")}`, fd);
  },

  download() {
    const id = val("dl_translId");
    const url = `/download/${id}${token ? `?token=${encodeURIComponent(token)}` : ""}`;
    log("Open download", url);
    window.open(url, "_blank", "noopener");
  },

  async deleteTranslation() {
    await apiFetch("DELETE", `/games/translate/${val("del_tr_transId")}`);
  },

  async getUsers() {
    const result = await apiFetch("GET", `/api/admin/users?page=${val("users_page")}&limit=${val("users_limit")}`);
    renderUsers(result.data);
  },

  async blockUser() {
    await apiFetch("PATCH", `/api/admin/users/${val("admin_userId")}/block`);
  },

  async unblockUser() {
    await apiFetch("PATCH", `/api/admin/users/${val("admin_userId")}/unblock`);
  },

  async warnUser() {
    await apiFetch("PATCH", `/api/admin/users/${val("admin_userId")}/warn`, { reason: val("warn_reason") });
  },

  async unwarnUser() {
    await apiFetch("PATCH", `/api/admin/users/${val("admin_userId")}/unwarn`);
  },

  async setRole() {
    await apiFetch("PATCH", `/api/admin/users/${val("admin_userId")}/role`, { role: val("role_value") });
  },

  async getNotifications() {
    await apiFetch("GET", "/api/notifications");
  },

  async createNotification() {
    await apiFetch("POST", "/api/admin/notifications", {
      title: val("notif_title"),
      message: val("notif_message"),
      isGlobal: $("notif_isGlobal").checked,
      userId: Number(val("notif_userId") || 0),
    });
  },

  async getModeration() {
    await apiFetch("GET", `/api/admin/moderation?page=${val("mod_page")}&limit=${val("mod_limit")}`);
  },

  async approve() {
    await apiFetch("PATCH", `/api/admin/moderation/${val("mod_transId")}/approve`);
  },

  async reject() {
    await apiFetch("PATCH", `/api/admin/moderation/${val("mod_transId")}/reject`, { reason: val("mod_reason") });
  },

  async changeStatus() {
    await apiFetch("PATCH", `/api/admin/moderation/${val("mod_transId")}/change-status/${val("mod_status")}`);
  },

  chatConnect() {
    if (!token) {
      log("Chat", { error: "Token is empty" });
      return;
    }
    if (chatSocket) return;

    const protocol = location.protocol === "https:" ? "wss" : "ws";
    const url = `${protocol}://${location.host}/api/chat/ws?token=${encodeURIComponent(token)}`;
    chatSocket = new WebSocket(url);

    chatSocket.onopen = () => {
      setChatStatus(true, "connected");
      appendChat("connected");
    };
    chatSocket.onmessage = (event) => {
      try {
        appendChat(formatJson(JSON.parse(event.data)));
      } catch {
        appendChat(event.data);
      }
    };
    chatSocket.onerror = () => appendChat("socket error");
    chatSocket.onclose = () => {
      setChatStatus(false, "disconnected");
      appendChat("disconnected");
      chatSocket = null;
    };
  },

  chatDisconnect() {
    if (chatSocket) chatSocket.close();
  },

  chatSend() {
    if (!chatSocket || chatSocket.readyState !== WebSocket.OPEN) {
      log("Chat", { error: "Socket is not open" });
      return;
    }
    const payload = { to: Number(val("chat_to")), text: val("chat_text") };
    chatSocket.send(JSON.stringify(payload));
    appendChat(`me -> ${payload.to}: ${payload.text}`);
  },

  async chatHistory() {
    await apiFetch("GET", `/api/chat/history/${val("chat_historyId")}`);
  },

  async rawRequest() {
    const method = val("raw_method").toUpperCase();
    const path = val("raw_path") || "/";
    const rawBody = val("raw_body");
    const body = ["POST", "PATCH", "PUT"].includes(method) && rawBody ? rawBody : undefined;
    await apiFetch(method, path, body);
  },
};

async function runAction(name, trigger) {
  const action = actions[name];
  if (!action) return;

  const previousText = trigger?.textContent;
  if (trigger?.tagName === "BUTTON") {
    trigger.disabled = true;
    trigger.textContent = "...";
  }

  try {
    await action();
  } catch (error) {
    if (name === "health") setServerStatus("warn", "server: error");
    log(name, { error: String(error) });
  } finally {
    if (trigger?.tagName === "BUTTON") {
      trigger.disabled = false;
      trigger.textContent = previousText;
    }
  }
}

function activateTab(name) {
  document.querySelectorAll(".nav-item").forEach((button) => {
    button.classList.toggle("active", button.dataset.tabTarget === name);
  });
  document.querySelectorAll(".tab-panel").forEach((panel) => {
    panel.classList.toggle("active", panel.id === `tab-${name}`);
  });
}

document.addEventListener("submit", (event) => {
  const form = event.target.closest("form[data-action]");
  if (!form) return;
  event.preventDefault();
  runAction(form.dataset.action, form.querySelector('button[type="submit"]'));
});

document.addEventListener("click", (event) => {
  const tab = event.target.closest("[data-tab-target]");
  if (tab) {
    activateTab(tab.dataset.tabTarget);
    return;
  }

  const selectGame = event.target.closest("[data-select-game]");
  if (selectGame) {
    setGameIdEverywhere(selectGame.dataset.selectGame);
    return;
  }

  const action = event.target.closest("button[data-action]");
  if (action) runAction(action.dataset.action, action);
});

$("healthBtn").addEventListener("click", () => runAction("health", $("healthBtn")));
$("clearLog").addEventListener("click", () => {
  $("log").textContent = "";
});
$("logoutBtn").addEventListener("click", () => setToken(""));
$("copyTokenBtn").addEventListener("click", async () => {
  if (!token) return;
  await navigator.clipboard.writeText(token);
  log("Token copied", "JWT copied to clipboard");
});

updateAuthStatus();
setChatStatus(false, "disconnected");
runAction("health", $("healthBtn"));