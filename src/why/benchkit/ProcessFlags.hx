package why.benchkit;

/**
	Process-level CLI flags for a compiled suite.
	Always print a console summary; optional `--json <path>` writes machine-readable results.
	Args come from `ProcessArgs` (`Sys.args()` on sys/node; `window.benchkitArgs` on browser `js`).
**/
class ProcessFlags {
	/** Path for JSON output when `--json` was passed; otherwise `null`. */
	public final jsonPath:Null<String>;

	function new(jsonPath:Null<String>) {
		this.jsonPath = jsonPath;
	}

	/**
		Parse suite process args. Recognizes `--json <path>`.
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
		return new ProcessFlags(jsonPath);
	}
}
