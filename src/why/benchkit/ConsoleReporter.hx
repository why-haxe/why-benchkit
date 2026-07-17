package why.benchkit;

import travix.Logger;

/**
	Human-readable suite summary via `travix.Logger` (sys + browser JS).
**/
class ConsoleReporter {
	function new() {}

	/**
		Print a console summary for `result`.
	**/
	public static function report(result:SuiteResult):Void {
		Logger.println('suite: ${result.name}');
		for (r in result.results) {
			Logger.println('  ${r.name}  ${formatOps(r.opsPerSec)} ops/sec  (${formatMs(r.totalMs)} ms, ${r.iterations} iter, ${r.warmup} warmup)');
		}
	}

	static function formatOps(opsPerSec:Float):String {
		if (!Math.isFinite(opsPerSec))
			return Std.string(opsPerSec);
		// Keep summary readable without locale-specific formatting.
		return Std.string(Math.round(opsPerSec * 100) / 100);
	}

	static function formatMs(totalMs:Float):String {
		if (!Math.isFinite(totalMs))
			return Std.string(totalMs);
		return Std.string(Math.round(totalMs * 1000) / 1000);
	}
}
