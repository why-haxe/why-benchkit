package why.benchkit.reporter;

import haxe.Json;
import haxe.io.Path;
import why.benchkit.BenchmarkResult;
import why.benchkit.Reporter;

/**
	Write benchmark JSON via `JsonWriter` (sys / node filesystem, or browser bridge).
**/
class JsonReporter implements Reporter {
	final resolvePath:(result:BenchmarkResult) -> String;

	public function new(resolvePath:(result:BenchmarkResult) -> String) {
		this.resolvePath = resolvePath;
	}

	/** Write to a fixed path (standalone `--json <path>`). */
	public static function toPath(path:String):JsonReporter {
		return new JsonReporter(_ -> path);
	}

	/** Write `<dir>/<result.target>.json` (host `--json-dir`). */
	public static function toDir(dir:String):JsonReporter {
		return new JsonReporter(result -> Path.join([dir, '${result.target}.json']));
	}

	public function report(result:BenchmarkResult):Void {
		final path = resolvePath(result);
		ensureParentDir(path);
		JsonWriter.write(path, Json.stringify(result));
	}

	static function ensureParentDir(filePath:String):Void {
		#if (js && !nodejs)
		// Browser writes go through the host bridge; no local mkdir.
		#else
		final parent = Path.directory(filePath);
		if (parent == null || parent == '' || sys.FileSystem.exists(parent))
			return;
		ensureParentDir(parent);
		if (!sys.FileSystem.exists(parent))
			sys.FileSystem.createDirectory(parent);
		#end
	}
}
