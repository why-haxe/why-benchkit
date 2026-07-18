package why.benchkit;

import haxe.Json;
import why.benchkit.reporter.JsonWriter;

/**
	Hand suite results from the suite process to the host.
	- browser `js`: `window.benchkitComplete(doc)` (object; hooks write RESULT path)
	- sys / `node`: write JSON to `WHY_BENCHKIT_RESULT`
**/
class ResultBridge {
	function new() {}

	public static function emit(doc:SuiteJsonDocument):Void {
		#if (js && !nodejs)
		completeBrowser(doc);
		#else
		final path = resultPath();
		if (path == null || path.length == 0)
			throw 'why.benchkit: ${BenchkitEnv.RESULT_PATH} is not set';
		JsonWriter.write(path, Json.stringify(doc));
		#end
	}

	public static function resultPath():Null<String> {
		#if (js && !nodejs)
		final fromWindow:Null<String> = untyped js.Browser.window.benchkitResultPath;
		if (fromWindow != null && fromWindow.length > 0)
			return fromWindow;
		return null;
		#else
		final fromEnv = Sys.getEnv(BenchkitEnv.RESULT_PATH);
		if (fromEnv == null || fromEnv.length == 0)
			return null;
		return fromEnv;
		#end
	}

	public static function isHostMode():Bool {
		return resultPath() != null;
	}

	#if (js && !nodejs)
	static function completeBrowser(doc:SuiteJsonDocument):Void {
		final complete:Null<(result:Dynamic) -> Void> = untyped js.Browser.window.benchkitComplete;
		if (complete == null) {
			throw "why.benchkit: window.benchkitComplete is not available "
				+ "(host must set TRAVIX_CONFIG_DIR to packaged .travix/; see .travix/README.md)";
		}
		// Puppeteer JSON-clones plain objects across the bridge.
		complete(doc);
	}
	#end
}
