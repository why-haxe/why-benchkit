package why.benchkit.reporter;

import travix.Logger;
import why.benchkit.BenchmarkResult;
import why.benchkit.Reporter;

/**
	Human-readable benchmark summary via `travix.Logger` (sys + browser JS).
**/
class ConsoleReporter implements Reporter {
	public function new() {}

	public function report(result:BenchmarkResult):Void {
		Logger.println('benchmark  (${result.target}, haxe ${result.haxeVersion})');
		for (suite in result.results) {
			Logger.println('suite: ${suite.name}');
			for (m in suite.results) {
				Logger.println('  ${m.name}  ${formatMs(m.duration.toFloat())} ms');
			}
		}
	}

	static function formatMs(totalMs:Float):String {
		if (!Math.isFinite(totalMs))
			return Std.string(totalMs);
		return Std.string(Math.round(totalMs * 1000) / 1000);
	}
}
