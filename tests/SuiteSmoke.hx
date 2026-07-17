import why.benchkit.Bench;

/**
	Phase 2 smoke: suite API on interp (summary via travix.Logger).
	Usage: haxe suite.hxml
**/
class SuiteSmoke {
	static function main():Void {
		final suite = Bench.suite({
			name: "suite_smoke",
			warmup: 50,
			iterations: 5_000,
		});

		suite.bench("sum.loop", () -> {
			var sum = 0;
			for (i in 0...100)
				sum += i;
			return sum;
		});

		suite.bench("sum.hot", () -> {
			var sum = 0;
			for (i in 0...50)
				sum += i;
			return sum;
		}, {
			iterations: 20_000,
			warmup: 100,
		});

		// Partial override: iterations only; warmup must stay at suite default.
		suite.bench("sum.partial", () -> {
			var sum = 0;
			for (i in 0...20)
				sum += i;
			return sum;
		}, {
			iterations: 8_000,
		});

		final result = suite.run();

		if (result.name != "suite_smoke")
			throw 'SuiteSmoke: unexpected suite name ${result.name}';
		if (result.results.length != 3)
			throw 'SuiteSmoke: expected 3 results, got ${result.results.length}';

		final a = result.results[0];
		if (a.name != "sum.loop" || a.iterations != 5_000 || a.warmup != 50)
			throw 'SuiteSmoke: unexpected first case ${a.name}/${a.iterations}/${a.warmup}';
		if (!(a.totalSeconds > 0) || !Math.isFinite(a.opsPerSec) || a.opsPerSec <= 0)
			throw 'SuiteSmoke: bad timing for sum.loop';

		final b = result.results[1];
		if (b.name != "sum.hot" || b.iterations != 20_000 || b.warmup != 100)
			throw 'SuiteSmoke: unexpected second case ${b.name}/${b.iterations}/${b.warmup}';
		if (!(b.totalSeconds > 0) || !Math.isFinite(b.opsPerSec) || b.opsPerSec <= 0)
			throw 'SuiteSmoke: bad timing for sum.hot';

		final c = result.results[2];
		if (c.name != "sum.partial" || c.iterations != 8_000 || c.warmup != 50)
			throw 'SuiteSmoke: unexpected partial override ${c.name}/${c.iterations}/${c.warmup}';
		if (!(c.totalSeconds > 0) || !Math.isFinite(c.opsPerSec) || c.opsPerSec <= 0)
			throw 'SuiteSmoke: bad timing for sum.partial';
	}
}
