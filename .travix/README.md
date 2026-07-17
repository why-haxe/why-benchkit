# Packaged travix config (browser JS)

why-benchkit ships this `.travix/` tree so browser `js` suite runs can write JSON without forking travix’s runner or writing into the consumer’s `.travix/`.

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
| `js/hooks.js` | `beforeGoto(page)` exposes `window.benchkitWriteFile(path, content)` via `page.exposeFunction`, writing with host `fs.writeFileSync`. |

`benchkitWriteFile` paths are resolved on the **host** (Node) relative to process cwd — after `Run` switches cwd, that is the consumer project. Prefer absolute paths from the host CLI when emitting `--json` / `--json-dir` outputs.

Do **not** use deprecated `bin/js/run.js` / `run.html` overrides for this bridge.
