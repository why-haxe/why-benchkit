package why.benchkit;

/**
	Write suite JSON to `path` on the current target.
	- sys / `node`: filesystem (`sys.io.File`).
	- browser `js`: `window.benchkitWriteFile(path, content)` (Phase 5 travix hooks).
**/
class JsonWriter {
	function new() {}

	public static function write(path:String, content:String):Void {
		#if (js && !nodejs)
		writeBrowser(path, content);
		#else
		sys.io.File.saveContent(path, content);
		#end
	}

	#if (js && !nodejs)
	/**
		Bridge installed by packaged `.travix/js/hooks.js` (Phase 5).
		Until then, calling `--json` on browser `js` throws if the hook is missing.
	**/
	static function writeBrowser(path:String, content:String):Void {
		final writeFile:Null<(path:String, content:String) -> Void> = untyped js.Browser.window.benchkitWriteFile;
		if (writeFile == null) {
			throw "why.benchkit: window.benchkitWriteFile is not available "
				+ "(install packaged travix hooks / TRAVIX_CONFIG_DIR; see Phase 5)";
		}
		writeFile(path, content);
	}
	#end
}
