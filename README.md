# why-benchkit

Micro-benchmark suites for [Haxe](https://haxe.org/). Write measures once, run them across targets with [travix](https://github.com/back2dos/travix), compare commits, and publish charts.

## Install

```bash
haxelib install why-benchkit
lix install haxelib:why-benchkit
```

Requires Haxe 4.3+.

## Quick start

1. Depend on `why-benchkit` and install your project dependencies.
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

Public instance methods on each suite are discovered as measures.

3. Run across targets:

```bash
haxelib run why-benchkit run --targets interp,node
# or
lix run why-benchkit run --targets interp,node --json-dir out/
```

## Measuring

When `@:warmup` / `@:iterations` (or the same fields on `Measure.run` opts) are **omitted**, measurement adapts: warmup stabilizes, then a time budget (default ~150 ms via `targetMs`) chooses how many timed iterations to run. Set either or both for fixed counts; explicit values always override.

After warmup and iteration resolution, each measure runs **N** independent timed loops (`sampleCount`, default **5**). `duration` is the mean of those samples (used for reporters, charts, and compare). Host `--samples` applies only when measure opts omit `sampleCount`.

**TODO:** Noise model / statistical comparison — v1 compare and reporters use mean `duration` → ops/sec (and a relative threshold for compare). Sample variance / median / tests are not used yet; `samples` are stored for that future work.

## Host commands

### `run`

```bash
haxelib run why-benchkit run --targets interp,neko,python,node,js,lua,cpp,jvm [--json-dir out/] [--samples 5]
# or
lix run why-benchkit run --targets interp,node --json-dir out/ --samples 5
```

`--targets` is required. Known targets: `interp,neko,python,node,js,lua,cpp,jvm`.

| Flag         | Default | Notes                                                     |
| ------------ | ------- | --------------------------------------------------------- |
| `--targets`  | —       | Required. Comma-separated list                            |
| `--json-dir` | off     | Write nested JSON under `<dir>/<sha>/` or `<dir>/_dirty/` |
| `--samples`  | `5`     | Independent timed loops per measure after warmup (`>= 1`) |

Install project deps before invoking the host. Console reporting always runs; with `--json-dir`, results land under a clean-commit SHA folder (or `_dirty/` when the tree is dirty / git is unavailable), plus folder and root manifests.

### `compare`

Run the same suite at two git SHAs, diff mean ops/sec, and print a verdict table.

```bash
haxelib run why-benchkit compare --base <sha-or-ref> --head <sha-or-ref> --targets node
# or
lix run why-benchkit compare --base origin/main --head HEAD --targets interp,node --samples 5 --threshold 0.10
```

| Flag                | Required | Default | Notes                                                   |
| ------------------- | -------- | ------- | ------------------------------------------------------- |
| `--base`            | yes      | —       | Baseline commit (full or unambiguous short SHA / ref)   |
| `--head`            | yes      | —       | Candidate commit                                        |
| `--targets`         | yes      | —       | Same as `run`                                           |
| `--samples`         | no       | `5`     | Passed through to both SHA runs                         |
| `--threshold`       | no       | `0.10`  | Relative ops/sec delta for “major” (default = 10%)      |
| `--fail-on-missing` | no       | off     | Non-zero exit if any measure exists on only one side    |
| `--post-pr-comment` | no       | off     | Post/update a markdown summary on the current GitHub PR |

Exit **0** when there is at least one paired measure and no major **degradations** (improvements / unchanged are fine). Exit **1** on major degradation, orchestration failure, or zero paired measures. Missing-side counts are always printed; they only fail the process with `--fail-on-missing`.

**TODO:** Allow customizing the per-worktree install command (today hard-coded `lix download`).

**TODO:** Noise model / statistical comparison (v1 is mean ± threshold only; `samples` are stored for later — see [Measuring](#measuring)).

#### Optional PR comment (`--post-pr-comment`)

Posts (or updates) a single markdown summary on the current GitHub PR after the table. Prefer the [`gh`](https://cli.github.com/) CLI when available; otherwise uses Actions env (`GITHUB_*` + token). Comment failure is warn-only and does not override the compare exit code.

```yaml
permissions:
  contents: read
  pull-requests: write
steps:
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0
  - run: lix run why-benchkit compare --base origin/main --head HEAD --targets node --post-pr-comment
```

### `html`

Generate a Chart.js page that fetches manifests and result JSON at runtime:

```bash
haxelib run why-benchkit html --out=bin/out.html --json-dir=out/
# or
lix run why-benchkit html --out=bin/out.html --json-dir=out/
```

Writes sibling `.css` / `.js` next to the HTML. Default fetch base is the relative path from the HTML file to `--json-dir`; override with `--json-base` when the deploy layout differs. Preview over HTTP (`file://` fetch will fail).

### `manifest`

Rebuild the root catalog from commit folders under `--json-dir` (skips `_dirty`):

```bash
haxelib run why-benchkit manifest --json-dir out/
# or
lix run why-benchkit manifest --json-dir out/
```

### `sync`

Additively copy a local JSON tree onto another git branch (skips `_dirty`; commits by default; `--push` optional):

```bash
haxelib run why-benchkit sync --source-dir=out/ --dest-branch=gh-pages --dest-dir=bench-data/
lix run why-benchkit sync --source-dir=out/ --dest-branch=gh-pages --dest-dir=bench-data/ --push
```

## GitHub Pages

Publish the viewer and JSON under the **same origin** so relative `fetch` works. Exclude `_dirty/` from anything you publish.

### Same-branch `docs/` layout

1. Accumulate history with a clean tree: `why-benchkit run --targets … --json-dir docs/bench-data/`
2. Generate the viewer: `why-benchkit html --out=docs/index.html --json-dir=docs/bench-data/`
3. Push `docs/` (or your Pages folder) and open over HTTPS.

```text
docs/
  index.html
  index.css
  index.js
  bench-data/
    manifest.json
    <full-sha>/…
```

### Sync onto a publish branch

When JSON should live on another branch (e.g. `gh-pages`):

```bash
why-benchkit sync --source-dir=out/ --dest-branch=gh-pages --dest-dir=bench-data/
# Add --push to also push origin/gh-pages
```

#### GitHub Actions requirements

| Requirement                                                                      | Why                                              |
| -------------------------------------------------------------------------------- | ------------------------------------------------ |
| `actions/checkout` with a token that can write                                   | Push needs write access                          |
| `permissions: contents: write`                                                   | Workflow token scope                             |
| Fetch dest branch history (`fetch-depth: 0` or `git fetch origin <dest-branch>`) | Worktree / orphan detection needs the remote ref |
| Configure `user.name` / `user.email` before sync                                 | Commit fails otherwise                           |

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

## Advanced

**JSON layout.** With `--json-dir`, results land as `<json-dir>/<sha|/_dirty>/<haxeVersion>/<target>.json` plus folder and root `manifest.json`; `_dirty/` is local-only and never listed in the root catalog.

**Browser JS.** For target `js`, the host injects reporter config via packaged travix hooks; you do not need a local `.travix`. See [`.travix/README.md`](.travix/README.md).

**Standalone reporter config.** Set `WHY_BENCHKIT_CONFIG` (native/node) or `window.why.benchkit` (browser) to a JSON object with `reporters` (default `console`; optional `json` + `outputDir`). Root `target` is required when using the json reporter.
