package why.benchkit;

/**
	Process argv for the suite CLI (standalone reporting).
	- sys / `node`: `Sys.args()`
	- browser `js`: `window.benchkitArgs` (string array) when set for standalone
	  `--json` use; empty when unset.

	Host-driven runs hand off via `WHY_BENCHKIT_RESULT` / `ResultBridge` and do
	not rely on these args for reporting.
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
