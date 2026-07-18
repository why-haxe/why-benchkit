package why.benchkit.reporter;

import haxe.Json;
import haxe.io.Path;
import why.benchkit.Reporter;
import why.benchkit.SuiteJsonDocument;

/**
	Write suite JSON via `JsonWriter` (sys / node filesystem, or browser bridge).
**/
class JsonReporter implements Reporter {
	final resolvePath:(doc:SuiteJsonDocument) -> String;

	public function new(resolvePath:(doc:SuiteJsonDocument) -> String) {
		this.resolvePath = resolvePath;
	}

	/** Write to a fixed path (standalone `--json <path>`). */
	public static function toPath(path:String):JsonReporter {
		return new JsonReporter(_ -> path);
	}

	/** Write `<dir>/<doc.target>.json` (host `--json-dir`). */
	public static function toDir(dir:String):JsonReporter {
		return new JsonReporter(doc -> Path.join([dir, '${doc.target}.json']));
	}

	public function report(doc:SuiteJsonDocument):Void {
		final path = resolvePath(doc);
		ensureParentDir(path);
		JsonWriter.write(path, Json.stringify(doc));
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
