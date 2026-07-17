package why.benchkit;

/**
	Write suite JSON to `path` on the current target.
	- sys / `node`: filesystem (`sys.io.File`).
	- browser `js`: `window.benchkitWriteFile(path, content)` from packaged
	  `.travix/js/hooks.js` (host sets `TRAVIX_CONFIG_DIR` to that config root).
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
		Bridge installed by packaged `.travix/js/hooks.js` when the host sets
		`TRAVIX_CONFIG_DIR` to the absolute path of that `.travix/` config root
		(replaces cwd `.travix` for the run; see `.travix/README.md`).
	**/
	static function writeBrowser(path:String, content:String):Void {
		final writeFile:Null<(path:String, content:String) -> Void> = untyped js.Browser.window.benchkitWriteFile;
		if (writeFile == null) {
			throw "why.benchkit: window.benchkitWriteFile is not available "
				+ "(set TRAVIX_CONFIG_DIR to the absolute packaged .travix/ path; see .travix/README.md)";
		}
		writeFile(path, content);
	}
	#end
}
