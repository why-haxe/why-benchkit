import why.benchkit.Bench;

/**
	Phase 1 smoke: measure a tiny loop on the interpreter and print ops/sec.
	Usage: haxe smoke.hxml
**/
class Smoke {
	static function main():Void {
		final r = Bench.measure(() -> {
			var sum = 0;
			for (i in 0...100)
				sum += i;
			return sum;
		}, {
			iterations: 10_000,
			warmup: 100,
		});

		if (r.iterations != 10_000 || r.warmup != 100)
			throw 'Smoke: unexpected iterations/warmup (${r.iterations}/${r.warmup})';
		if (!(r.totalSeconds > 0) || !(r.totalMs > 0))
			throw 'Smoke: expected positive timing, got totalSeconds=${r.totalSeconds}';
		if (!Math.isFinite(r.opsPerSec) || r.opsPerSec <= 0)
			throw 'Smoke: expected finite positive opsPerSec, got ${r.opsPerSec}';

		Sys.println('iterations=${r.iterations} warmup=${r.warmup}');
		Sys.println('totalSeconds=${r.totalSeconds} totalMs=${r.totalMs}');
		Sys.println('opsPerSec=${r.opsPerSec}');
	}
}
