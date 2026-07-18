package why.benchkit.reporter;

import travix.Logger;
import why.benchkit.BenchmarkResult;
import why.benchkit.MeasureResult;
import why.benchkit.Reporter;
import why.unit.time.Second;

/**
	Human-readable benchmark summary via `travix.Logger` (sys + browser JS).
**/
class ConsoleReporter implements Reporter {
	public function new() {}

	public function report(result:BenchmarkResult):Void {
		Logger.println('benchmark  (${result.target}, haxe ${result.haxeVersion})');
		for (suite in result.results) {
			Logger.println('suite: ${suite.name}');
			final nameWidth = maxNameWidth(suite.results);
			final rows = [for (m in suite.results) formatRow(m)];
			final opsWidth = maxOpsWidth(rows);
			for (i in 0...rows.length) {
				final m = suite.results[i];
				final row = rows[i];
				Logger.println('  ${StringTools.rpad(m.name, " ", nameWidth)}  ${StringTools.lpad(row.ops, " ", opsWidth)} ops/sec  (${row.ms} ms, ${m.iterations} iter, ${m.warmup} warmup)');
			}
		}
	}

	static function formatRow(m:MeasureResult):{ops:String, ms:String} {
		final seconds:Float = (m.duration : Second).toFloat();
		final opsPerSec = if (seconds > 0) m.iterations / seconds else Math.POSITIVE_INFINITY;
		return {
			ops: formatOps(opsPerSec),
			ms: formatMs(m.duration.toFloat()),
		};
	}

	static function maxNameWidth(results:Array<MeasureResult>):Int {
		var w = 0;
		for (m in results)
			if (m.name.length > w)
				w = m.name.length;
		return w;
	}

	static function maxOpsWidth(rows:Array<{ops:String, ms:String}>):Int {
		var w = 0;
		for (row in rows)
			if (row.ops.length > w)
				w = row.ops.length;
		return w;
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
