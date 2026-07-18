# Packaged travix config (browser JS)

why-benchkit ships this `.travix/` tree so browser `js` suite runs receive
reporter config (and can write JSON via `JsonReporter`) without forking
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
| `js/hooks.js` | `beforeGoto(page)` injects config and file-write bridge (see below). |

### Config inject (`WHY_BENCHKIT_CONFIG`)

When the host sets **`WHY_BENCHKIT_CONFIG`** (JSON), hooks parse it and set
`window.why.benchkit` before page scripts run. The suite `Config.load` reads that
object (same shape as native env). Reporting finishes in the suite process — there
is no result handoff back to the host.

If the env var is missing or empty, `window.why.benchkit` is set to `null` and
the suite defaults to the console reporter.

### JsonReporter file writes

`window.benchkitWriteFile(path, content)` is always exposed so browser
`JsonWriter` / `JsonReporter` can persist `outputPath` to the host filesystem.

`benchkitWriteFile` paths are resolved on the **host** (Node) relative to process cwd — after `Run` switches cwd, that is the consumer project.

Do **not** use deprecated `bin/js/run.js` / `run.html` overrides for this bridge.
