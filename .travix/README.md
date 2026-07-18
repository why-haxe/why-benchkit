# Packaged travix config (browser JS)

why-benchkit ships this `.travix/` tree so browser `js` suite runs can hand results
back to the host (and optionally write JSON when run standalone) without forking
travix’s runner or writing into the consumer’s `.travix/`.

## `TRAVIX_CONFIG_DIR`

Travix loads hooks from `$TRAVIX_CONFIG_DIR/js/hooks.js` when set; otherwise from `cwd/.travix/js/hooks.js`.

For why-benchkit-driven `js` runs, the host must set **`TRAVIX_CONFIG_DIR` to the absolute path of this packaged `.travix/` directory** (the config root), for example:

```bash
export TRAVIX_CONFIG_DIR=/absolute/path/to/why-benchkit/.travix
```

That value **replaces** the consumer cwd `.travix` for that run — it is not a merge. Consumers who need their own travix hooks when not using benchkit keep using cwd `.travix` as usual.

## Hooks

| File | Role |
| ---- | ---- |
| `js/hooks.js` | `beforeGoto(page)` exposes host bridges (see below). |

### Host mode (`WHY_BENCHKIT_RESULT`)

When the host sets **`WHY_BENCHKIT_RESULT`**, hooks:

1. Expose `window.benchkitComplete(result)` — prefer a plain object (Puppeteer JSON-clones it); a JSON string is also accepted. Writes to the result path on the host via `fs.writeFileSync`.
2. Set `window.benchkitResultPath` so the suite enters handoff mode (skips local reporters).

The Haxe host then reads that file and runs reporters (console / `--json-dir`).

### Standalone browser `--json`

`window.benchkitWriteFile(path, content)` remains available so standalone suite
`JsonWriter` / `JsonReporter` can persist `--json` output from the page.

`benchkitWriteFile` paths are resolved on the **host** (Node) relative to process cwd — after `Run` switches cwd, that is the consumer project.

Do **not** use deprecated `bin/js/run.js` / `run.html` overrides for this bridge.
