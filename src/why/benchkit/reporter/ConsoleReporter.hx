package why.benchkit.reporter;

import travix.Logger;
import why.benchkit.Reporter;
import why.benchkit.SuiteJsonDocument;

/**
	Human-readable suite summary via `travix.Logger` (sys + browser JS).
**/
class ConsoleReporter implements Reporter {
	public function new() {}

	public function report(doc:SuiteJsonDocument):Void {
		Logger.println('suite: ${doc.suite}  (${doc.target})');
		for (r in doc.results) {
			Logger.println('  ${r.name}  ${formatOps(r.opsPerSec)} ops/sec  (${formatMs(r.totalMs)} ms, ${r.iterations} iter, ${r.warmup} warmup)');
		}
	}

	static function formatOps(opsPerSec:Float):String {
		if (!Math.isFinite(opsPerSec))
			return Std.string(opsPerSec);
		return Std.string(Math.round(opsPerSec * 100) / 100);
	}

	static function formatMs(totalMs:Float):String {
		if (!Math.isFinite(totalMs))
			return Std.string(totalMs);
		return Std.string(Math.round(totalMs * 1000) / 1000);
	}
}
