# why-benchkit

Micro-benchmark suite API and multi-target host runner for [Haxe](https://haxe.org/).
Haxe package: `why.benchkit`. Target install/compile/run is delegated to [travix](https://github.com/back2dos/travix).

Reporting finishes in the suite process. The host only orchestrates travix runs and injects reporter config.

## Install

**haxelib**

```bash
haxelib install why-benchkit
```

**lix** (pin a version when published)

```bash
lix install haxelib:why-benchkit
# or pin: lix install haxelib:why-benchkit#0.0.1
```

**local / git checkout**

```bash
haxelib dev why-benchkit /path/to/why-benchkit
# or with lix, point haxe_libraries/why-benchkit.hxml at this repo
```

Requires Haxe 4.3+ (see `.haxerc`). Declares `why-unit`, `travix`, `tink_cli`, and `hx3compat` in `haxelib.json`.

## Suite API

In the consumer project:

1. Depend on `why-benchkit` and install your project dependencies yourself.
2. Add a `bench.hxml` with `-lib why-benchkit` and a `-main` that calls `Runner.run`:

```hxml
# bench.hxml
-cp tests
-lib why-benchkit
-main BenchSuite
```

```haxe
import why.benchkit.Runner;

class BenchSuite {
	static function main() {
		Runner.run([
			new MySuite(),
		]);
	}
}

@:name("my_lib") // optional: defaults to class name
class MySuite {
	public function new() {}

	@:warmup(50) // optional: overrides default
	@:iterations(100000) // optional: overrides default
	@:name("do-work") // optional: defaults to method name
	public function doWork() {
		return work(); // return a value so DCE cannot erase the work
	}
}
```

The macro discovers each suite’s public instance methods and treats them as measure items.

Low-level escape hatch:

```haxe
import why.benchkit.Measure;

final r = Measure.run(() -> work(), { name: "op", iterations: 1000, warmup: 10 });
// r.name, r.duration (why.unit.time.Millisecond)
```

## Reporter config

At the start of `Runner.run`, reporters are loaded from config:

- **Native / node:** `WHY_BENCHKIT_CONFIG` (JSON string)
- **Browser `js`:** `window.why.benchkit` (same shape; injected by packaged travix hooks)
- **Missing / empty:** default `{ "reporters": [{ "name": "console" }] }`

```json
{
  "target": "node",
  "reporters": [
    { "name": "console" },
    { "name": "json", "outputDir": "out" }
  ]
}
```

Root `target` is required when a `json` reporter is present. The JSON file is written to `<outputDir>/<haxeVersion>/<target>.json` (CLI/host target in the filename, not `BenchmarkResult.target`).

Each reporter’s `report(result:BenchmarkResult)` runs in the suite process. There is no result handoff back to the host.

## Host runner (multi-target)

From the consumer project:

```bash
haxelib run why-benchkit run --targets interp,neko,python,node,js,lua,cpp,jvm [--json-dir out/]
# or
lix run why-benchkit run --targets interp,node --json-dir out/
```

`--targets` is required. Known targets: `interp,neko,python,node,js,lua,cpp,jvm`.

Single-target:

```bash
haxelib run why-benchkit run --targets interp --json-dir out/
```

Per target, the host runs travix `install()` + `buildAndRun()` against `bench.hxml` (`TRAVIX_HXML`), and sets `WHY_BENCHKIT_CONFIG` so the suite reports itself (console always; plus a JSON file under `--json-dir` when requested). Install haxelib/lix project deps before invoking the host.

With `--json-dir`, results land under `<json-dir>/<full-sha>/` when the git working tree is clean, or `<json-dir>/_dirty/` when dirty / git is unavailable. After the run, the host writes that folder’s `manifest.json` and rebuilds the root clean-commit catalog (`commits` ordered by each folder’s commit-manifest `timestamp`).

Rebuild the root catalog alone (idempotent scan of commit folders; skips `_dirty`):

```bash
haxelib run why-benchkit manifest --json-dir out/
# or
lix run why-benchkit manifest --json-dir out/
```

### Static viewer (`html`)

Generate a Chart.js page that **fetches** root/commit manifests and result JSON at runtime (nothing embedded):

```bash
haxelib run why-benchkit html --out=bin/out.html --json-dir=out/
# or
lix run why-benchkit html --out=bin/out.html --json-dir=out/
```

- Writes sibling `.css` / `.js` next to the HTML (same basename as `--out`, e.g. `out.html` → `out.css` / `out.js`).
- Default fetch base is the relative path from the HTML file to `--json-dir`. Override with `--json-base` when the deploy layout differs (e.g. `--json-base=./data/`).
- UI: dropdowns for haxe version, CLI target, and suite; one duration chart per measurement. Optional `_dirty` overlay when `_dirty/manifest.json` exists (local only; not in the published series).
- Preview over HTTP — `file://` fetch will fail. Examples: `npx serve` or `python -m http.server`.

### Fixture smoke (`fixture/foo`)

From a checkout of this repo:

```bash
cd fixture/foo
lix run why-benchkit run --targets interp,node --json-dir=bench-out/
# → bench-out/<sha>/… or bench-out/_dirty/… plus folder + root manifests

lix run why-benchkit manifest --json-dir=bench-out/
lix run why-benchkit html --out=bench-viewer/index.html --json-dir=bench-out/

# from repo root (or any parent that can serve both paths):
cd ../..
python3 -m http.server 8765
# open http://127.0.0.1:8765/fixture/foo/bench-viewer/
```

Confirm nested `<haxeVersion>/<target>.json`, folder `manifest.json` (`timestamp` + `files`), root `manifest.json` listing clean SHAs only, and charts loading over HTTP (enable dirty overlay if `_dirty/` is present).

## JSON output

**Host** — nested JSON under a commit or `_dirty` folder (recommended; works for browser `js` too):

```bash
haxelib run why-benchkit run --targets node,js --json-dir out/
# clean tree → out/<full-sha>/<haxeVersion>/node.json, …/js.json
# dirty tree → out/_dirty/<haxeVersion>/node.json, …/js.json
# plus out/<sha|_dirty>/manifest.json and out/manifest.json (clean SHAs only)
```

Layout:

```text
out/
  manifest.json              # root catalog: { "commits": ["<sha>", ...] } oldest → newest
  <full-sha>/
    manifest.json            # { "timestamp": <git commit ms>, "files": ["4.3.7/node.json", ...] }
    <haxeVersion>/<target>.json
  _dirty/                    # local only; never listed in root manifest.json
    manifest.json            # { "timestamp": <last run ms>, "files": [...] }
    <haxeVersion>/<target>.json
```

**Timestamp semantics**

| Location | `timestamp` meaning |
| --- | --- |
| `<sha>/manifest.json` | Git **commit** time (ms), used to order the root catalog |
| `_dirty/manifest.json` | Last **benchmark run** time (ms); overwritten every dirty run |
| Result JSON `timestamp` | Run reference only — charts / catalog order use commit-manifest `timestamp` |

**Filename target vs document `target`:** the `.json` filename and root config `target` are the CLI/host target (`interp`, `node`, `js`, …). Document `BenchmarkResult.target` is compile-time `target.name` (e.g. `"eval"` under `--interp`). Charts and file discovery key on the filename / CLI target.

**Standalone** — set `WHY_BENCHKIT_CONFIG` yourself before running the compiled suite (browser: inject `window.why.benchkit`). Use root `target` plus json `outputDir` pointing at the commit or `_dirty` folder as in [Reporter config](#reporter-config).

Document shape:

```json
{
  "haxeVersion": "4.3.x",
  "target": "js",
  "timestamp": 1710000000000,
  "commitHash": "683bdb9f256b894c61e526efd8f86f78e5b3658c",
  "results": [
    {
      "name": "my_lib",
      "results": [
        {
          "name": "do-work",
          "duration": 12.3,
          "iterations": 1000,
          "warmup": 10
        }
      ]
    }
  ]
}
```

`timestamp` here is run time (ms). `duration` is milliseconds (`why.unit.time.Millisecond`), serialized as a JSON number. Catalog / chart x-axis order uses commit-manifest `timestamp`, not this field.

## GitHub Pages

Publish the viewer and the JSON tree under the **same origin** so relative `fetch` works.

1. Accumulate history with a clean working tree: `why-benchkit run --targets … --json-dir docs/bench-data/` (or any folder you will deploy).
2. Generate the viewer into the Pages root (or a subpath):  
   `why-benchkit html --out=docs/index.html --json-dir=docs/bench-data/`  
   Relative `json-base` is computed from those paths; pass `--json-base=…` only if the published URL layout differs.
3. **Exclude `_dirty/`** from the published tree (local temp only). Root `manifest.json` never lists it; still omit the folder so it is not accidentally served.
4. Push `docs/` (or your Pages folder). Open the site over HTTPS — no server API required; Chart.js loads from CDN.

Project Pages example layout:

```text
docs/
  index.html
  index.css
  index.js
  bench-data/
    manifest.json
    <full-sha>/…
    # no _dirty/
```

Local preview of the same layout: `python3 -m http.server` from the parent of `docs/`, then open `/docs/`.

## Browser JS (`TRAVIX_CONFIG_DIR`)

For target `js`, travix runs the suite in a browser (puppeteer). Config inject uses packaged hooks:

1. This package ships hooks at `.travix/js/hooks.js`.
2. Before `JsCommand.buildAndRun`, the host sets `TRAVIX_CONFIG_DIR` to the **absolute** path of that packaged `.travix/` directory.
3. Hooks read `WHY_BENCHKIT_CONFIG` and set `window.why.benchkit` before page scripts run.
4. `window.benchkitWriteFile(path, content)` remains available so browser `JsonReporter` can write the full nested file path on the host filesystem.

`TRAVIX_CONFIG_DIR` **replaces** the consumer’s cwd `.travix` for that run (not a merge). You do not need to write into the consumer’s `.travix/`, and you should not use deprecated `bin/js/run.js` / `run.html` overrides.

Details: [`.travix/README.md`](.travix/README.md).

## Packaging note

`haxelib submit .` skips names starting with `.`, so it would drop `.travix/`. Release with either:

```bash
./scripts/pack.sh          # → why-benchkit.zip (includes .travix/js/hooks.js)
haxelib submit why-benchkit.zip
```

or travix release, which uses `travix.release.files` in `haxelib.json` (lists `.travix` explicitly). The zip must contain `src/` (including `why.benchkit.Run`), `haxelib.json`, `README.md`, and `.travix/js/hooks.js`.
