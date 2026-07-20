import why.benchkit.Measure;

/**
	Measure-core smoke on interp: fixed mode + time-budgeted iterations.
	Usage: haxe smoke.hxml
**/
class Smoke {
	static function main():Void {
		final work = () -> {
			var sum = 0;
			for (i in 0...100)
				sum += i;
			return sum;
		};

		final r = Measure.run(work, {
			name: "sum.loop",
			iterations: 10_000,
			warmup: 100,
		});

		if (r.name != "sum.loop")
			throw 'Smoke: unexpected name ${r.name}';
		final ms = r.duration.toFloat();
		if (!Math.isFinite(ms) || !(ms > 0))
			throw 'Smoke: expected positive finite duration, got $ms';

		Sys.println('name=${r.name} durationMs=$ms');

		// Fixed warmup + omitted iterations → duration near targetMs (loose CI band).
		final targetMs = 80.0;
		final budgeted = Measure.run(work, {
			name: "sum.budgeted",
			warmup: 100,
			targetMs: targetMs,
		});
		final budgetedMs = budgeted.duration.toFloat();
		if (budgeted.iterations < 1)
			throw 'Smoke: expected calibrated iterations >= 1, got ${budgeted.iterations}';
		if (!Math.isFinite(budgetedMs) || !(budgetedMs > 0))
			throw 'Smoke: expected positive finite budgeted duration, got $budgetedMs';
		// ±50% of target — loose enough for interp / busy CI.
		final lo = targetMs * 0.5;
		final hi = targetMs * 1.5;
		if (budgetedMs < lo || budgetedMs > hi)
			throw 'Smoke: budgeted duration $budgetedMs ms not in [$lo, $hi] for targetMs=$targetMs (iters=${budgeted.iterations})';

		Sys.println('name=${budgeted.name} durationMs=$budgetedMs iterations=${budgeted.iterations}');
	}
}
