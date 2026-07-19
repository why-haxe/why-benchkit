package why.benchkit.host;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
	Generate a static viewer shell that fetches root/commit manifests and
	benchmark JSON at runtime (no embedding). Compatible with GitHub Pages
	when HTML and `--json-dir` share an origin with stable relative URLs.
**/
class HostHtml {
	function new() {}

	/**
		Write the viewer HTML to `outPath`. `jsonDir` must exist as a directory.
		`jsonBase` is the URL prefix used by `fetch` (trailing slash). When null,
		computed as the relative path from the HTML’s parent directory to
		`jsonDir` (so local layout matches deploy layout).
	**/
	public static function generate(outPath:String, jsonDir:String, ?jsonBase:String):Void {
		final outAbs = Path.normalize(outPath);
		final jsonAbs = Path.normalize(jsonDir);

		if (!FileSystem.exists(jsonAbs) || !FileSystem.isDirectory(jsonAbs))
			throw 'why-benchkit: not a directory: $jsonAbs';

		final outDir = Path.directory(outAbs);
		if (outDir != null && outDir.length > 0)
			ensureDir(outDir);

		final base = switch jsonBase {
			case null | '':
				ensureTrailingSlash(relativePath(outDir == null || outDir.length == 0 ? Sys.getCwd() : outDir, jsonAbs));
			case s:
				ensureTrailingSlash(StringTools.trim(s));
		};

		File.saveContent(outAbs, renderHtml(base));
	}

	/**
		Relative path from `fromDir` to `toPath` using `/` separators (URL-safe).
		Both paths should be absolute or equally rooted.
	**/
	public static function relativePath(fromDir:String, toPath:String):String {
		final fromParts = splitPath(Path.normalize(fromDir));
		final toParts = splitPath(Path.normalize(toPath));

		var i = 0;
		final n = fromParts.length < toParts.length ? fromParts.length : toParts.length;
		while (i < n && fromParts[i] == toParts[i])
			i++;

		final ups:Array<String> = [];
		for (_ in i...fromParts.length)
			ups.push('..');
		final downs = toParts.slice(i);
		final parts = ups.concat(downs);
		return parts.length == 0 ? '.' : parts.join('/');
	}

	static function splitPath(path:String):Array<String> {
		// Normalize separators so Windows `\` paths still produce URL-safe `/` relatives.
		final parts = Path.normalize(path).split('\\').join('/').split('/');
		return [for (p in parts) if (p.length > 0) p];
	}

	static function ensureTrailingSlash(s:String):String {
		if (s.length == 0 || s == '.')
			return './';
		return StringTools.endsWith(s, '/') ? s : s + '/';
	}

	static function ensureDir(path:String):Void {
		final normalized = Path.normalize(path);
		if (FileSystem.exists(normalized)) {
			if (!FileSystem.isDirectory(normalized))
				throw 'why-benchkit: not a directory: $normalized';
			return;
		}
		final parent = Path.directory(normalized);
		if (parent != null && parent.length > 0 && parent != normalized)
			ensureDir(parent);
		FileSystem.createDirectory(normalized);
	}

	static function renderHtml(jsonBase:String):String {
		final escapedBase = escapeJsString(jsonBase);
		return '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>why-benchkit</title>
<style>
  :root { color-scheme: light dark; font-family: ui-sans-serif, system-ui, sans-serif; }
  body { margin: 1.5rem; line-height: 1.45; max-width: 56rem; }
  h1 { font-size: 1.25rem; margin: 0 0 0.5rem; }
  .meta { color: #666; font-size: 0.9rem; margin-bottom: 1.25rem; }
  .err { color: #b00020; white-space: pre-wrap; }
  .note { background: #f4f4f5; padding: 0.75rem 1rem; border-radius: 6px; font-size: 0.9rem; margin-bottom: 1.25rem; }
  @media (prefers-color-scheme: dark) {
    .meta { color: #aaa; }
    .note { background: #222; }
  }
  section { margin: 1.25rem 0; }
  h2 { font-size: 1.05rem; margin: 0 0 0.5rem; }
  ul { padding-left: 1.25rem; }
  li { margin: 0.35rem 0; }
  code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.85rem; }
  pre { overflow: auto; padding: 0.75rem; background: #f4f4f5; border-radius: 6px; }
  @media (prefers-color-scheme: dark) { pre { background: #1a1a1a; } }
  button.linkish {
    background: none; border: none; padding: 0; color: #0b57d0; cursor: pointer;
    font: inherit; text-decoration: underline;
  }
  @media (prefers-color-scheme: dark) { button.linkish { color: #8ab4f8; } }
  .sha { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.85rem; }
  .empty { color: #666; font-style: italic; }
</style>
</head>
<body>
  <h1>why-benchkit</h1>
  <p class="meta">Static viewer scaffold — loads manifests and JSON via <code>fetch</code> (no charts yet).</p>
  <p class="note">Serve this page over HTTP (e.g. <code>npx serve</code> or <code>python -m http.server</code>).
  Opening via <code>file://</code> will fail because browsers block local <code>fetch</code>.</p>
  <p class="meta">JSON base: <code id="json-base"></code></p>
  <div id="status">Loading…</div>
  <section id="clean" hidden>
    <h2>Clean commits</h2>
    <div id="clean-body"></div>
  </section>
  <section id="dirty" hidden>
    <h2>Dirty overlay (<code>_dirty</code>)</h2>
    <div id="dirty-body"></div>
  </section>
  <section id="sample" hidden>
    <h2>Sample JSON</h2>
    <p class="meta" id="sample-path"></p>
    <pre id="sample-body"></pre>
  </section>
<script>
(function () {
  const JSON_BASE = "' + escapedBase + '";
  document.getElementById("json-base").textContent = JSON_BASE;

  const statusEl = document.getElementById("status");
  const cleanSec = document.getElementById("clean");
  const cleanBody = document.getElementById("clean-body");
  const dirtySec = document.getElementById("dirty");
  const dirtyBody = document.getElementById("dirty-body");
  const sampleSec = document.getElementById("sample");
  const samplePath = document.getElementById("sample-path");
  const sampleBody = document.getElementById("sample-body");

  function url(rel) {
    return JSON_BASE + rel.replace(/^\\/+/, "");
  }

  async function fetchJson(rel) {
    const res = await fetch(url(rel));
    if (!res.ok) {
      const err = new Error("HTTP " + res.status + " for " + rel);
      err.status = res.status;
      throw err;
    }
    return res.json();
  }

  function fmtTime(ms) {
    if (typeof ms !== "number" || !isFinite(ms)) return String(ms);
    try { return new Date(ms).toISOString() + " (" + ms + ")"; }
    catch (e) { return String(ms); }
  }

  function shortSha(id) {
    return id.length > 12 ? id.slice(0, 12) : id;
  }

  function fileList(prefix, files, onPick) {
    if (!files || !files.length) {
      const p = document.createElement("p");
      p.className = "empty";
      p.textContent = "No result files listed.";
      return p;
    }
    const ul = document.createElement("ul");
    for (const f of files) {
      const li = document.createElement("li");
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "linkish";
      btn.textContent = f;
      btn.addEventListener("click", () => onPick(prefix + f));
      li.appendChild(btn);
      ul.appendChild(li);
    }
    return ul;
  }

  async function showSample(rel) {
    sampleSec.hidden = false;
    samplePath.textContent = rel;
    sampleBody.textContent = "Loading…";
    try {
      const data = await fetchJson(rel);
      sampleBody.textContent = JSON.stringify(data, null, 2);
    } catch (e) {
      sampleBody.textContent = String(e && e.message ? e.message : e);
    }
  }

  function emptyNote(text) {
    const p = document.createElement("p");
    p.className = "empty";
    p.textContent = text;
    return p;
  }

  function errNote(text) {
    const p = document.createElement("p");
    p.className = "err";
    p.textContent = text;
    return p;
  }

  function renderCommit(id, manifest) {
    const wrap = document.createElement("div");
    const title = document.createElement("p");
    const sha = document.createElement("span");
    sha.className = "sha";
    sha.title = id;
    sha.textContent = shortSha(id);
    title.appendChild(sha);
    if (id.length > 12) {
      const full = document.createElement("code");
      full.style.marginLeft = "0.5rem";
      full.style.fontSize = "0.75rem";
      full.textContent = id;
      title.appendChild(full);
    }
    wrap.appendChild(title);

    const meta = document.createElement("p");
    meta.className = "meta";
    meta.textContent = "timestamp: " + fmtTime(manifest.timestamp);
    wrap.appendChild(meta);

    const prefix = id + "/";
    wrap.appendChild(fileList(prefix, manifest.files, showSample));
    return wrap;
  }

  async function main() {
    try {
      const root = await fetchJson("manifest.json");
      const commits = Array.isArray(root.commits) ? root.commits : [];
      cleanSec.hidden = false;
      if (!commits.length) {
        cleanBody.textContent = "";
        cleanBody.appendChild(emptyNote("No clean commits in root manifest.json."));
      } else {
        cleanBody.textContent = "";
        let firstSample = null;
        for (const id of commits) {
          const man = await fetchJson(id + "/manifest.json");
          cleanBody.appendChild(renderCommit(id, man));
          if (!firstSample && man.files && man.files.length)
            firstSample = id + "/" + man.files[0];
        }
        if (firstSample) await showSample(firstSample);
      }

      try {
        const dirty = await fetchJson("_dirty/manifest.json");
        dirtySec.hidden = false;
        dirtyBody.textContent = "";
        const meta = document.createElement("p");
        meta.className = "meta";
        meta.textContent = "timestamp: " + fmtTime(dirty.timestamp);
        dirtyBody.appendChild(meta);
        dirtyBody.appendChild(fileList("_dirty/", dirty.files, showSample));
      } catch (e) {
        dirtySec.hidden = false;
        dirtyBody.textContent = "";
        if (e && e.status === 404) {
          dirtyBody.appendChild(emptyNote("No _dirty/manifest.json (404)."));
        } else {
          dirtyBody.appendChild(errNote("Dirty probe failed: " + String(e && e.message ? e.message : e)));
        }
      }

      statusEl.textContent = "Loaded.";
    } catch (e) {
      statusEl.className = "err";
      statusEl.textContent = "Failed to load root manifest.json: " + String(e && e.message ? e.message : e)
        + "\\nServe the page and JSON tree over HTTP from a common origin.";
    }
  }

  main();
})();
</script>
</body>
</html>
';
	}

	static function escapeJsString(s:String):String {
		return s.split('\\')
			.join('\\\\')
			.split('"')
			.join('\\"')
			.split('\n')
			.join('\\n')
			.split('\r')
			.join('\\r')
			.split('<')
			.join('\\u003c')
			.split('\u2028')
			.join('\\u2028')
			.split('\u2029')
			.join('\\u2029');
	}
}
