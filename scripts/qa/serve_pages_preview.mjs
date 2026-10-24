// Local-only preview using the built Pages worker and a filesystem ASSETS adapter.
// This verifies worker routing locally; it is not a Cloudflare deployment.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { resolve, extname, sep } from "node:path";
import { pathToFileURL } from "node:url";

const root = resolve(process.argv[2] ?? "build/pwa/site");
const { default: worker } = await import(
  pathToFileURL(resolve(root, "_worker.js"))
);
const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".wasm": "application/wasm",
  ".svg": "image/svg+xml",
  ".mp4": "video/mp4",
};
const assets = {
  async fetch(request) {
    let path;
    try {
      path = resolve(
        root,
        "." + decodeURIComponent(new URL(request.url).pathname),
      );
    } catch {
      return new Response("Invalid path", { status: 400 });
    }
    if (path !== root && !path.startsWith(root + sep))
      return new Response("Not found", { status: 404 });
    try {
      try {
        if ((await stat(path)).isDirectory()) path = resolve(path, "index.html");
      } catch {
        // Pages resolves extensionless public HTML paths through ASSETS.
        if (extname(path) || !(await stat(path + ".html")).isFile())
          throw new Error("Not found");
        path += ".html";
      }
      return new Response(await readFile(path), {
        headers: {
          "Content-Type": ["__admin_shell", "__app_shell"].some(name => path.endsWith(sep + name))
            ? "text/html; charset=utf-8"
            : mime[extname(path)] ?? "application/octet-stream",
          "Cache-Control": "no-store",
        },
      });
    } catch {
      return new Response("Not found", { status: 404 });
    }
  },
};
const server = createServer(async (req, res) => {
  try {
    const request = new Request(`http://${req.headers.host}${req.url}`, {
      method: req.method,
    });
    const response = await worker.fetch(request, { ASSETS: assets });
    res.writeHead(response.status, Object.fromEntries(response.headers));
    res.end(
      req.method === "HEAD"
        ? undefined
        : Buffer.from(await response.arrayBuffer()),
    );
  } catch {
    res.writeHead(500);
    res.end("Preview failed");
  }
});
server.listen(Number(process.env.MOBIO_PREVIEW_PORT ?? 0), "127.0.0.1", () => {
  console.log(`Pages preview: http://127.0.0.1:${server.address().port}`);
});
