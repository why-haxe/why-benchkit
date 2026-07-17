# why-benchkit

Micro-benchmark suite API and multi-target host runner for [Haxe](https://haxe.org/).
Haxe package: `why.benchkit`. Target install/compile/run is delegated to [travix](https://github.com/back2dos/travix).

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

Requires Haxe 4.3+ (see `.haxerc`). Declares `travix` (and `hx3compat`) in `haxelib.json`.

## Suite API

In the consumer project:

1. Depend on `why-benchkit` (and keep a root `haxelib.json` so travix `InstallCommand` can install deps).
2. Add a travix-style `tests.hxml` with `-lib why-benchkit` and a `-main` that calls `suite.run()`:

```hxml
# tests.hxml
-cp tests
-lib why-benchkit
-main BenchSuite
```

```haxe
import why.benchkit.Bench;

class BenchSuite {
  static function main() {
    final suite = Bench.suite({
      name: "my_lib",
      warmup: 50,
      iterations: 10_000,
    });

    suite.bench("op.name", () -> {
      return doWork(); // return a value so DCE cannot erase the work
    });

    suite.bench("op.hot", () -> hot(), {
      iterations: 50_000,
      warmup: 100,
    });

    suite.run(); // always prints a summary; honors --json / host JSON env
  }
}
```

Low-level escape hatch:

```haxe
final r = Bench.measure(() -> work(), { iterations: 1000, warmup: 10 });
// r.totalSeconds, r.opsPerSec, r.iterations
```

## Host runner (multi-target)

From the consumer project:

```bash
haxelib run why-benchkit run --targets interp,neko,python,node,js,lua,cpp,jvm [--json-dir out/]
# or
lix run why-benchkit run --targets interp,node --json-dir out/
```

Defaults when `--targets` is omitted: `interp,neko,python,node,js,lua,cpp,jvm`.

Single-target:

```bash
haxelib run why-benchkit run --targets interp --json-dir out/
```

The host installs shared deps, then per target runs travix `install()` + `buildAndRun()` against `tests.hxml`.

## JSON output

**Suite process** (one compiled target) — always prints a console summary; optional file on sys / `node`:

```bash
# filesystem write (exact invocation depends on how you compile/run the suite)
# e.g. after building for node/neko/cpp/…:
./suite --json out/node.json
```

**Host** — one JSON file per target (recommended; works for browser `js` too):

```bash
haxelib run why-benchkit run --targets node,js --json-dir out/
# → out/node.json, out/js.json
```

(The host sets `WHY_BENCHKIT_JSON` because travix does not forward runtime argv on most targets.)

For browser `js`, prefer the host + `--json-dir` (see below); a bare suite `--json` path alone is not enough without the packaged hooks.

Suggested shape:

```json
{
  "suite": "my_lib",
  "target": "node",
  "haxeVersion": "4.3.x",
  "timestamp": "2026-07-17T12:00:00Z",
  "results": [
    {
      "name": "op.name",
      "iterations": 10000,
      "warmup": 50,
      "totalMs": 12.3,
      "opsPerSec": 81234.0
    }
  ]
}
```

## Browser JS (`TRAVIX_CONFIG_DIR`)

For target `js`, travix runs the suite in a browser (puppeteer). JSON write uses a host bridge:

1. This package ships hooks at `.travix/js/hooks.js`.
2. Before `JsCommand.buildAndRun`, the host sets `TRAVIX_CONFIG_DIR` to the **absolute** path of that packaged `.travix/` directory.
3. `beforeGoto` exposes `window.benchkitWriteFile(path, content)` via `page.exposeFunction` (host `fs.writeFileSync`).

`TRAVIX_CONFIG_DIR` **replaces** the consumer’s cwd `.travix` for that run (not a merge). You do not need to write into the consumer’s `.travix/`, and you should not use deprecated `bin/js/run.js` / `run.html` overrides.

Details: [`.travix/README.md`](.travix/README.md).

## Packaging note

`haxelib submit .` skips names starting with `.`, so it would drop `.travix/`. Release with either:

```bash
./scripts/pack.sh          # → why-benchkit.zip (includes .travix/js/hooks.js)
haxelib submit why-benchkit.zip
```

or travix release, which uses `travix.release.files` in `haxelib.json` (lists `.travix` explicitly). The zip must contain `src/`, `Run.hx`, `haxelib.json`, `README.md`, and `.travix/js/hooks.js`.
