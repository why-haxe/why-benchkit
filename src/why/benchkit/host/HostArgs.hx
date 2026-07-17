package why.benchkit.host;

/**
	Parse host CLI args for `run`.

	Flags:
	- `--targets a,b,c` — comma-separated travix targets (default: interp,neko,python,node,js,lua,cpp,jvm)
	- `--json-dir <dir>` — write per-target JSON to `<dir>/<target>.json`
**/
class HostArgs {
	function new() {}

	/**
		Parse args. Returns `null` when `--help` / `-h` was requested.
		Throws a string message on invalid input.
	**/
	public static function parse(args:Array<String>):Null<HostOptions> {
		var targets:Null<Array<String>> = null;
		var jsonDir:Null<String> = null;
		var i = 0;
		while (i < args.length) {
			final arg = args[i];
			switch (arg) {
				case '--targets':
					if (i + 1 >= args.length)
						throw 'why-benchkit run: --targets requires a comma-separated list';
					targets = parseTargets(args[i + 1]);
					i += 2;
				case '--json-dir':
					if (i + 1 >= args.length)
						throw 'why-benchkit run: --json-dir requires a directory path';
					final dir = args[i + 1];
					if (dir.length == 0)
						throw 'why-benchkit run: --json-dir path must be non-empty';
					jsonDir = dir;
					i += 2;
				case '--help' | '-h':
					return null;
				case unknown if (StringTools.startsWith(unknown, '-')):
					throw 'why-benchkit run: unknown option: $unknown';
				case positional:
					throw 'why-benchkit run: unexpected argument: $positional';
			}
		}
		return new HostOptions(targets ?? HostTargets.DEFAULT.copy(), jsonDir);
	}

	static function parseTargets(raw:String):Array<String> {
		final parts = raw.split(',').map(s -> StringTools.trim(s)).filter(s -> s.length > 0);
		if (parts.length == 0)
			throw 'why-benchkit run: --targets list must not be empty';
		for (t in parts) {
			if (!HostTargets.isKnown(t))
				throw 'why-benchkit run: unknown target "$t" (expected one of: ${HostTargets.DEFAULT.join(", ")})';
		}
		return parts;
	}
}
