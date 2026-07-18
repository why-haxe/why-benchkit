#!/usr/bin/env bash
# Build a haxelib-installable zip that keeps packaged travix hooks.
#
# Why: `haxelib submit .` / haxelib's zipDirectory skips names starting with `.`,
# which would drop `.travix/js/hooks.js` required for browser `js` JSON writes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:-why-benchkit.zip}"
rm -f "$OUT"

# Explicit file list (same intent as haxelib.json travix.release.files).
zip -r "$OUT" \
  haxelib.json \
  README.md \
  src \
  .travix \
  -x '*.DS_Store' \
  -x '*__MACOSX*'

echo "==> wrote $OUT"

# Sanity: classpath root + packaged hooks must be present.
missing=0
for path in \
  haxelib.json \
  README.md \
  src/why/benchkit/Run.hx \
  src/why/benchkit/Runner.hx \
  .travix/js/hooks.js \
  .travix/README.md
do
  if ! unzip -l "$OUT" | awk '{print $4}' | grep -qx -- "$path"; then
    echo "error: missing from zip: $path" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

# Confirm haxelib.json classPath and main.
python3 - "$OUT" <<'PY'
import json, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
info = json.loads(z.read("haxelib.json"))
assert info.get("classPath") == "src", info.get("classPath")
assert info.get("main") == "why.benchkit.Run", info.get("main")
deps = info.get("dependencies") or {}
assert "why-unit" in deps, deps
assert "travix" in deps, deps
assert "tink_cli" in deps, deps
assert "hx3compat" in deps, deps
release = ((info.get("travix") or {}).get("release") or {}).get("files") or []
assert ".travix" in release, release
assert "Run.hx" not in release, release
names = set(z.namelist())
assert ".travix/js/hooks.js" in names, sorted(n for n in names if "travix" in n or "hooks" in n)
assert "src/why/benchkit/Runner.hx" in names, sorted(n for n in names if "Runner" in n)
print("ok: classPath=src, main=why.benchkit.Run, deps, travix.release.files, hooks present")
PY

echo "==> pack ok"
