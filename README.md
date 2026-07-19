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

## JSON output

**Host** — one nested JSON file per target (recommended; works for browser `js` too):

```bash
haxelib run why-benchkit run --targets node,js --json-dir out/
# → out/<haxeVersion>/node.json, out/<haxeVersion>/js.json
# (CLI target id in the filename; e.g. --targets interp → out/<haxeVersion>/interp.json)
```

**Standalone** — set `WHY_BENCHKIT_CONFIG` yourself before running the compiled suite (browser: inject `window.why.benchkit`). Use root `target` plus json `outputDir` as in [Reporter config](#reporter-config).

Document shape:

```json
{
  "haxeVersion": "4.3.x",
  "target": "js",
  "timestamp": "2026-07-18T12:00:00Z",
  "results": [
    {
      "name": "my_lib",
      "results": [
        {
          "name": "do-work",
          "duration": 12.3
        }
      ]
    }
  ]
}
```

Document `target` is the compile-time define `target.name` (e.g. `"eval"` under `--interp`, `"js"` for JS) — not necessarily the same string as the CLI/`--json-dir` filename. `duration` is milliseconds (`why.unit.time.Millisecond`), serialized as a JSON number.

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
