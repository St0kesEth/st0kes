// Serves the paper: a handful of static files, read once and gzipped at boot.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { gzipSync } from "node:zlib";
import { extname, join, normalize } from "node:path";

const ROOT = new URL("./web/", import.meta.url).pathname;
const PORT = process.env.PORT || 4173;
const TYPES = { ".html":"text/html; charset=utf-8", ".js":"text/javascript; charset=utf-8",
  ".css":"text/css; charset=utf-8", ".json":"application/json; charset=utf-8",
  ".svg":"image/svg+xml", ".png":"image/png", ".ico":"image/x-icon" };

const cache = new Map();
async function load(path) {
  if (cache.has(path)) return cache.get(path);
  const raw = await readFile(join(ROOT, path));
  const type = TYPES[extname(path)] || "application/octet-stream";
  const entry = { type, raw, gz: /text|javascript|json|svg/.test(type) ? gzipSync(raw, { level: 9 }) : null };
  cache.set(path, entry);
  return entry;
}

createServer(async (req, res) => {
  let path = decodeURIComponent((req.url || "/").split("?")[0]);
  if (path === "/") path = "/index.html";
  path = normalize(path).replace(/^(\.\.[/\\])+/, "").replace(/^\/+/, "");
  try {
    const fl = await load(path);
    const gz = fl.gz && /\bgzip\b/.test(req.headers["accept-encoding"] || "");
    const body = gz ? fl.gz : fl.raw;
    res.writeHead(200, { "content-type": fl.type, "content-length": body.length,
      // the page and its numbers are regenerated together and must never be
      // served as a mismatched pair, so neither is cached across a deploy
      "cache-control": /\.(html|js)$/.test(path) ? "no-cache" : "public, max-age=3600",
      ...(gz ? { "content-encoding": "gzip" } : {}), "x-content-type-options": "nosniff" });
    res.end(req.method === "HEAD" ? undefined : body);
  } catch {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    res.end("not found");
  }
}).listen(PORT, "0.0.0.0", () => console.log(`paper on ${PORT}`));
