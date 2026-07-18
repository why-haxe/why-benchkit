package why.benchkit.reporter;

import haxe.Json;
import haxe.io.Path;
import why.benchkit.BenchmarkResult;
import why.benchkit.Reporter;

/**
	Write benchmark JSON via `JsonWriter` (sys / node filesystem, or browser bridge).
**/
class JsonReporter implements Reporter {
	final outputPath:String;

	public function new(outputPath:String) {
		this.outputPath = outputPath;
	}

	public function report(result:BenchmarkResult):Void {
		ensureParentDir(outputPath);
		write(outputPath, Json.stringify(result, '  '));
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

	static function write(path:String, content:String):Void {
		#if (js && !nodejs)
		switch untyped js.Browser.window.benchkitWriteFile {
			case null:
				throw "why.benchkit: window.benchkitWriteFile is not available "
					+ "(set TRAVIX_CONFIG_DIR to the absolute packaged .travix/ path; see .travix/README.md)";
			case f:
				f(path, content);
		}
		#else
		sys.io.File.saveContent(path, content);
		#end
	}
}
