const http = require("http");
const net = require("net");
const fs = require("fs");
const path = require("path");

const FRONT_PORT = Number(process.env.TEST_WEB_PORT || 3000);
const BACKEND = {
  host: process.env.API_HOST || "127.0.0.1",
  port: Number(process.env.API_PORT || 8080),
};

const PROXY_PREFIXES = [
  "/api",
  "/cards",
  "/games",
  "/download",
  "/static",
  "/swagger",
  "/health",
];

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
};

function isProxyPath(url) {
  return PROXY_PREFIXES.some((prefix) => url === prefix || url.startsWith(`${prefix}/`) || url.startsWith(`${prefix}?`));
}

function targetPath(url) {
  return url === "/health" ? "/" : url;
}

function proxyHttp(req, res) {
  const options = {
    host: BACKEND.host,
    port: BACKEND.port,
    method: req.method,
    path: targetPath(req.url),
    headers: { ...req.headers, host: `${BACKEND.host}:${BACKEND.port}` },
  };

  const proxyReq = http.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode || 502, proxyRes.headers);
    proxyRes.pipe(res);
  });

  proxyReq.on("error", (error) => {
    res.writeHead(502, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ error: "Go API is unavailable", backend: BACKEND, detail: String(error) }));
  });

  req.pipe(proxyReq);
}

function serveStatic(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  const pathname = url.pathname === "/" ? "/index.html" : url.pathname;
  const safeRoot = path.resolve(__dirname);
  const filePath = path.resolve(safeRoot, `.${pathname}`);

  if (!filePath.startsWith(safeRoot + path.sep) && filePath !== safeRoot) {
    res.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Forbidden");
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not found");
      return;
    }

    res.writeHead(200, { "Content-Type": MIME[path.extname(filePath)] || "application/octet-stream" });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  if (isProxyPath(req.url)) {
    proxyHttp(req, res);
    return;
  }
  serveStatic(req, res);
});

server.on("upgrade", (req, clientSocket, head) => {
  if (!isProxyPath(req.url)) {
    clientSocket.destroy();
    return;
  }

  const backend = net.connect(BACKEND.port, BACKEND.host, () => {
    let raw = `${req.method} ${targetPath(req.url)} HTTP/1.1\r\n`;
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      const key = req.rawHeaders[i];
      const value = key.toLowerCase() === "host" ? `${BACKEND.host}:${BACKEND.port}` : req.rawHeaders[i + 1];
      raw += `${key}: ${value}\r\n`;
    }
    raw += "\r\n";

    backend.write(raw);
    if (head?.length) backend.write(head);
    clientSocket.pipe(backend);
    backend.pipe(clientSocket);
  });

  backend.on("error", () => clientSocket.destroy());
  clientSocket.on("error", () => backend.destroy());
});

server.listen(FRONT_PORT, () => {
  console.log(`Test web: http://localhost:${FRONT_PORT}`);
  console.log(`Proxy target: http://${BACKEND.host}:${BACKEND.port}`);
});