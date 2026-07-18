package why.benchkit.reporter;

import travix.Logger;
import why.benchkit.BenchmarkResult;
import why.benchkit.Reporter;
import why.unit.time.Millisecond;

class ConsoleReporter implements Reporter {
	public function new() {}

	public function report(result:BenchmarkResult):Void {
		Logger.println('benchmark  (${result.target}, haxe ${result.haxeVersion})');
		for (suite in result.results) {
			Logger.println('suite: ${suite.name}');
			for (m in suite.results) {
				Logger.println('  ${m.name}  ${formatDuration(m.duration)}');
			}
		}
	}

	static function formatDuration(duration:Millisecond):String {
		return Std.int(duration.toFloat()) + duration.symbol;
	}
}
