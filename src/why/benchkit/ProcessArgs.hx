package why.benchkit;

/**
	Process argv for the suite CLI.
	- sys / `node`: `Sys.args()`
	- browser `js`: `window.benchkitArgs` (string array), set by packaged
	  `.travix/js/hooks.js` from `WHY_BENCHKIT_JSON` when the host drives `js` runs.
	  Empty when unset.
	Host `--json-dir` primarily uses env `WHY_BENCHKIT_JSON` (see `ProcessFlags`);
	under `haxe --interp`, `Sys.args()` also includes compiler args, so a literal
	`--json <path>` in travix rest would be visible — prefer the env for all targets.
**/
class ProcessArgs {
	function new() {}

	public static function get():Array<String> {
		#if (js && !nodejs)
		return browserArgs();
		#else
		return Sys.args();
		#end
	}

	#if (js && !nodejs)
	static function browserArgs():Array<String> {
		final raw:Dynamic = untyped js.Browser.window.benchkitArgs;
		if (raw == null)
			return [];
		if (Std.isOfType(raw, Array))
			return (raw : Array<String>);
		return [];
	}
	#end
}
