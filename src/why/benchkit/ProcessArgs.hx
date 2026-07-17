package why.benchkit;

/**
	Process argv for the suite CLI.
	- sys / `node`: `Sys.args()`
	- browser `js`: `window.benchkitArgs` (string array), set by the host
	  (Phase 6) when driving browser runs. Empty when unset.
	Note: under `haxe --interp`, `Sys.args()` includes compiler args; travix still
	appends suite flags after `--interp`, so `--json <path>` remains visible to parse.
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
