package why.benchkit;

/**
	Process-level CLI flags for a standalone suite run.
	Optional `--json <path>` selects a `JsonReporter` output path.
	Args come from `ProcessArgs` (`Sys.args()` on sys/node; `window.benchkitArgs`
	on browser `js` when set for standalone use).

	Host-driven runs use `WHY_BENCHKIT_RESULT` + `ResultBridge` instead; they do
	not consult these flags for reporting.
**/
class ProcessFlags {
	/** Path for JSON output when `--json` / `WHY_BENCHKIT_JSON` was set; otherwise `null`. */
	public final jsonPath:Null<String>;

	function new(jsonPath:Null<String>) {
		this.jsonPath = jsonPath;
	}

	/**
		Parse suite process args. Recognizes `--json <path>`, then falls back to
		env `WHY_BENCHKIT_JSON` (standalone / embedding).
		Throws if `--json` is present without a following path.
	**/
	public static function parse(args:Array<String>):ProcessFlags {
		var jsonPath:Null<String> = null;
		var i = 0;
		while (i < args.length) {
			final arg = args[i];
			if (arg == "--json") {
				if (i + 1 >= args.length)
					throw "why.benchkit: --json requires a path argument";
				final path = args[i + 1];
				if (path.length == 0)
					throw "why.benchkit: --json path must be non-empty";
				jsonPath = path;
				i += 2;
			} else {
				i += 1;
			}
		}
		if (jsonPath == null)
			jsonPath = jsonPathFromEnv();
		return new ProcessFlags(jsonPath);
	}

	static function jsonPathFromEnv():Null<String> {
		#if (js && !nodejs)
		return null;
		#else
		final fromEnv = Sys.getEnv(BenchkitEnv.JSON_PATH);
		if (fromEnv == null || fromEnv.length == 0)
			return null;
		return fromEnv;
		#end
	}
}
