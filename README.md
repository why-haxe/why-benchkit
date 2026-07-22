# why-benchkit

Micro-benchmark suite API and multi-target host runner for [Haxe](https://haxe.org/).
Haxe package: `why.benchkit`. Target install/compile/run is delegated to [travix](https://github.com/back2dos/travix).

Reporting finishes in the suite process. The host only orchestrates travix runs and injects reporter config. There is **no HostReporter**, sockets, or other IPC for result handoff — results reach the host only via JSON on disk (plus console output in the suite process).

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

	// Omit @:warmup / @:iterations for adaptive measure (see below).
	@:warmup(50) // optional: fixed warmup count
	@:iterations(100000) // optional: fixed timed iterations
	@:name("do-work") // optional: defaults to method name
	public function doWork() {
		return work(); // return a value so DCE cannot erase the work
	}
}
```

The macro discovers each suite’s public instance methods and treats them as measure items.

### Adaptive measure

When `@:warmup` / `@:iterations` (or the same fields on `Measure.run` opts) are **omitted**, measurement adapts instead of using fixed defaults. Explicit values always override.

| `iterations` | `warmup` | Behavior |
| --- | --- | --- |
| omitted | omitted | Adaptive warmup, then time-budgeted timed loop |
| set | omitted | Adaptive warmup, then exactly `iterations` timed runs |
| omitted | set | Fixed warmup, then time-budgeted timed loop |
| set | set | Fixed warmup + fixed iterations |

Time-budgeted mode targets ~`targetMs` of timed work (default **150** ms) by calibrating iteration count after warmup. Adaptive warmup stops when successive batch costs stabilize (or hits a hard time/iteration cap). Results always report the **actual** `iterations` and `warmup` counts used.

After warmup and iteration resolution, `Measure.run` executes **N** independent timed loops (`MeasureOptions.sampleCount`, default **5**). `MeasureResult.samples` holds each loop’s wall time; `duration` is their **arithmetic mean** (headline for reporters, charts, and compare). Calibration probes (when time-budgeting) are outside `samples`.

When using `Runner`, host-injected `sampleCount` (from `run` / `compare` `--samples`) applies only if the measure opts omit `sampleCount`. Precedence: explicit measure opts **>** host config **>** `5`.

**TODO:** Noise model / statistical comparison — v1 compare and reporters use mean `duration` → ops/sec (and a relative threshold for compare). Sample variance / median / tests are not used yet; `samples` are stored for that future work.

Low-level escape hatch:

```haxe
import why.benchkit.Measure;

// Fully adaptive (omitted iterations/warmup); default sampleCount = 5:
final a = Measure.run(() -> work(), { name: "op" });
// a.iterations / a.warmup are the counts actually used;
// a.samples.length == 5; a.duration is mean(samples)

// Fixed mode (both set) — same as pre-adaptive for given numbers:
final r = Measure.run(() -> work(), { name: "op", iterations: 1000, warmup: 10 });
// r.name, r.duration (why.unit.time.Millisecond), r.samples

// Optional knobs: shorter time budget and/or fewer samples:
final b = Measure.run(() -> work(), { name: "op", targetMs: 100, sampleCount: 3 });
```

## Reporter config

At the start of `Runner.run`, reporters are loaded from config:

- **Native / node:** `WHY_BENCHKIT_CONFIG` (JSON string)
- **Browser `js`:** `window.why.benchkit` (same shape; injected by packaged travix hooks)
- **Missing / empty:** default `{ "reporters": [{ "name": "console" }] }`

```json
{
  "target": "node",
  "sampleCount": 5,
  "reporters": [
    { "name": "console" },
    { "name": "json", "outputDir": "out" }
  ]
}
```

Root `target` is required when a `json` reporter is present. The JSON file is written to `<outputDir>/<haxeVersion>/<target>.json` (CLI/host target in the filename, not `BenchmarkResult.target`). Optional top-level `sampleCount` is injected by the host (`--samples`) and applied by `Runner` when measure opts omit it.

Each reporter’s `report(result:BenchmarkResult)` runs in the suite process. There is no result handoff back to the host (no HostReporter / IPC).

## Host runner (multi-target)

From the consumer project:

```bash
haxelib run why-benchkit run --targets interp,neko,python,node,js,lua,cpp,jvm [--json-dir out/] [--samples 5]
# or
lix run why-benchkit run --targets interp,node --json-dir out/ --samples 5
```

`--targets` is required. Known targets: `interp,neko,python,node,js,lua,cpp,jvm`.

| Flag | Default | Notes |
| --- | --- | --- |
| `--targets` | — | Required. Comma-separated list |
| `--json-dir` | off | Nested JSON under `<dir>/<sha>/` or `<dir>/_dirty/` |
| `--samples` | `5` | Independent timed loops per measure after warmup (`>= 1`) |

Single-target:

```bash
haxelib run why-benchkit run --targets interp --json-dir out/
```

Per target, the host runs travix `install()` + `buildAndRun()` against `bench.hxml` (`TRAVIX_HXML`), and sets `WHY_BENCHKIT_CONFIG` so the suite reports itself (console always; plus a JSON file under `--json-dir` when requested). `--samples` becomes top-level `sampleCount` in that config. Install haxelib/lix project deps before invoking the host.

With `--json-dir`, results land under `<json-dir>/<full-sha>/` when the git working tree is clean, or `<json-dir>/_dirty/` when dirty / git is unavailable. After the run, the host writes that folder’s `manifest.json` and rebuilds the root clean-commit catalog (`commits` ordered by each folder’s commit-manifest `timestamp`).

Rebuild the root catalog alone (idempotent scan of commit folders; skips `_dirty`):

```bash
haxelib run why-benchkit manifest --json-dir out/
# or
lix run why-benchkit manifest --json-dir out/
```

Additively sync a local JSON tree onto another git branch (skips `_dirty`; commits by default; `--push` optional):

```bash
haxelib run why-benchkit sync --source-dir=out/ --dest-branch=gh-pages --dest-dir=bench-data/
lix run why-benchkit sync --source-dir=out/ --dest-branch=gh-pages --dest-dir=bench-data/ --push
```

See [GitHub Pages → Sync](#sync-onto-a-publish-branch-sync) for Actions requirements.

### Compare two commits (`compare`)

Run the same suite at two git SHAs, diff mean ops/sec, and print a verdict table. Compare creates its own **OS-temp** `json-dir` (not a user `--json-dir` flag) outside the repo and both worktrees.

```bash
haxelib run why-benchkit compare --base <sha-or-ref> --head <sha-or-ref> --targets node
# or
lix run why-benchkit compare --base origin/main --head HEAD --targets interp,node --samples 5 --threshold 0.10
```

| Flag | Required | Default | Notes |
| --- | --- | --- | --- |
| `--base` | yes | — | Baseline commit (full or unambiguous short SHA / ref) |
| `--head` | yes | — | Candidate commit |
| `--targets` | yes | — | Same as `run` |
| `--samples` | no | `5` | Passed through to both SHA runs |
| `--threshold` | no | `0.10` | Relative ops/sec delta for “major” (default = 10%) |
| `--fail-on-missing` | no | off | Non-zero exit if any measure exists on only one side |

**What it does**

1. Creates a unique OS-temp `json-dir` (e.g. under `$TMPDIR` / `TEMP`).
2. For each of `--base` and `--head`: `git worktree add` (clean detached checkout) → **`lix download`** in that worktree → `HostRun` with the temp `json-dir` and `--samples`.
3. Asserts JSON landed under `<tmp>/<full-sha>/…` (fails on `_dirty` or SHA mismatch).
4. Loads results, diffs mean ops/sec (`iterations / (durationMs / 1000)`), prints a table, exits.
5. Removes worktrees and the temp `json-dir` in `try/finally` when possible; OS temp reclamation is the safety net if the process exits hard.

**Exit codes**

| Code | When |
| --- | --- |
| `0` | At least one paired measure and no major **degradations** (improvements / unchanged OK); missing sides alone do not fail unless `--fail-on-missing` |
| `1` | Major degradation, orchestration / load failure, `_dirty` / SHA folder mismatch, **zero** paired measures, or `--fail-on-missing` with any missing-side pair |

Missing-side counts are always printed. Pairing key: `(haxeVersion, target, suite, measure)` using the CLI/host target from the JSON filename.

**TODO:** Allow customizing the per-worktree install command (today hard-coded `lix download`).

**TODO:** Noise model / statistical comparison (v1 is mean ± threshold only; `samples` are stored for later — see [Adaptive measure](#adaptive-measure)).

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
# optional: sync JSON onto another branch (see GitHub Pages → Sync)
# lix run why-benchkit sync --source-dir=bench-out/ --dest-branch=gh-pages --dest-dir=bench-data/

# from repo root (or any parent that can serve both paths):
cd ../..
python3 -m http.server 8765
# open http://127.0.0.1:8765/fixture/foo/bench-viewer/
```

Confirm nested `<haxeVersion>/<target>.json`, folder `manifest.json` (`timestamp` + `files`), root `manifest.json` listing clean SHAs only, and charts loading over HTTP (enable dirty overlay if `_dirty/` is present).

Optional compare smoke against two commits in this fixture (needs `lix` on `PATH` and a clean history with at least two SHAs that build the suite):

```bash
cd fixture/foo
lix run why-benchkit compare --base <base-sha> --head <head-sha> --targets interp
```

### Local verify (samples / compare)

From a checkout of this repo (interp smokes; no consumer project required):

```bash
haxe smoke.hxml              # Measure sampling + mean duration (default N=5, targetMs 150)
haxe compare.hxml            # Pure Compare.diff / verdicts
haxe hostcomparecmd.hxml     # Host compare load + table + exit policy (synthetic JSON)
haxe hostcompare.hxml        # Worktree + OS-temp json-dir + lix download + HostRun (needs git + lix)
haxe check-run.hxml          # CLI entry compiles; prints why-benchkit help (includes compare)
```

Node-oriented fixture run (writes JSON under `fixture/foo/bench-out/`):

```bash
cd fixture/foo
lix run why-benchkit run --targets interp,node --json-dir=bench-out/ --samples 5
```

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
          "warmup": 10,
          "samples": [12.1, 12.4, 12.2, 12.5, 12.3]
        }
      ]
    }
  ]
}
```

`timestamp` here is run time (ms). `duration` is milliseconds (`why.unit.time.Millisecond`), serialized as a JSON number — the **mean** of `samples` when sampling is used. `samples` is an array of per-loop wall times (length = N). Catalog / chart x-axis order uses commit-manifest `timestamp`, not this field.

## GitHub Pages

Publish the viewer and the JSON tree under the **same origin** so relative `fetch` works.

### Same-branch `docs/` layout

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

### Sync onto a publish branch (`sync`)

When JSON should live on another branch (e.g. `gh-pages`) instead of `docs/` on main:

```bash
# After accumulating results under out/ on the current branch:
why-benchkit sync --source-dir=out/ --dest-branch=gh-pages --dest-dir=bench-data/
# Commit only (default). Add --push to also push origin/gh-pages:
why-benchkit sync --source-dir=out/ --dest-branch=gh-pages --dest-dir=bench-data/ --push
```

- **Additive:** copies each clean `<sha>/` from `--source-dir` into `--dest-dir` on `--dest-branch` (overwrites matching shas; keeps dest-only shas). Never copies `_dirty/`. Rebuilds root `manifest.json` on the dest tree.
- Uses a temporary `git worktree` (current checkout can be detached — fine on GitHub Actions).
- If `--dest-branch` does not exist locally or on `origin`, creates an orphan empty branch.
- Commits when the dest tree changed; no empty commits. `--push` runs `git push origin HEAD:<dest-branch>`.

#### GitHub Actions requirements

| Requirement | Why |
| --- | --- |
| `actions/checkout` with a token that can write (`GITHUB_TOKEN` or PAT) | Push needs write access |
| `permissions: contents: write` | Workflow token scope |
| Fetch dest branch history (`fetch-depth: 0` **or** `git fetch origin <dest-branch>` before sync) | Worktree / orphan detection needs the remote ref |
| Configure `user.name` / `user.email` before sync | Commit fails otherwise (Actions does not set them by default) |
| Detached HEAD is fine | Sync never checks out the dest branch in the main workspace |

```yaml
permissions:
  contents: write
steps:
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0
  - run: |
      git config user.name "github-actions[bot]"
      git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  # … run benches into e.g. out/ …
  - run: lix run why-benchkit sync --source-dir=out/ --dest-branch=gh-pages --dest-dir=bench-data/ --push
```

Branch protection / required reviews on the publish branch may block `GITHUB_TOKEN` pushes — use a PAT or relax rules for that branch.

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
