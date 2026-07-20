import why.benchkit.Measure;
import why.benchkit.MeasureResult;

/**
	Measure-core smoke on interp: fixed mode, adaptive matrix, bounds, validation.
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

		assertFixedFixed(work);
		assertOmittedIterations(work);
		assertOmittedWarmup(work);
		assertMaxWarmupBound();
		assertInvalidOpts(work);

		Sys.println("Smoke ok");
	}

	/** set/set — fixed warmup + fixed iterations (pre-adaptive path). */
	static function assertFixedFixed(work:() -> Int):Void {
		final r = Measure.run(work, {
			name: "sum.loop",
			iterations: 10_000,
			warmup: 100,
		});

		if (r.name != "sum.loop")
			throw 'Smoke: unexpected name ${r.name}';
		if (r.iterations != 10_000)
			throw 'Smoke: expected iterations 10000, got ${r.iterations}';
		if (r.warmup != 100)
			throw 'Smoke: expected warmup 100, got ${r.warmup}';
		assertPositiveFiniteMs(r, "fixed");

		Sys.println('name=${r.name} durationMs=${r.duration.toFloat()} iterations=${r.iterations} warmup=${r.warmup}');
	}

	/** omitted/set — duration near targetMs (±50%, CI-friendly). */
	static function assertOmittedIterations(work:() -> Int):Void {
		final targetMs = 80.0;
		final budgeted = Measure.run(work, {
			name: "sum.budgeted",
			warmup: 100,
			targetMs: targetMs,
		});
		final budgetedMs = budgeted.duration.toFloat();
		if (budgeted.iterations < 1)
			throw 'Smoke: expected calibrated iterations >= 1, got ${budgeted.iterations}';
		if (budgeted.warmup != 100)
			throw 'Smoke: expected fixed warmup 100, got ${budgeted.warmup}';
		assertPositiveFiniteMs(budgeted, "budgeted");
		assertNearTargetMs(budgetedMs, targetMs, budgeted.iterations);

		Sys.println('name=${budgeted.name} durationMs=$budgetedMs iterations=${budgeted.iterations}');
	}

	/** set/omitted and omitted/omitted — adaptive warmup runs and reports count. */
	static function assertOmittedWarmup(work:() -> Int):Void {
		final fixedIters = Measure.run(work, {
			name: "sum.adaptive_warmup",
			iterations: 5_000,
			maxWarmupMs: 500,
		});
		if (fixedIters.iterations != 5_000)
			throw 'Smoke: expected fixed iterations 5000, got ${fixedIters.iterations}';
		if (fixedIters.warmup < 1)
			throw 'Smoke: expected adaptive warmup > 0, got ${fixedIters.warmup}';
		assertPositiveFiniteMs(fixedIters, "adaptive_warmup");

		Sys.println('name=${fixedIters.name} warmup=${fixedIters.warmup} iterations=${fixedIters.iterations}');

		final full = Measure.run(work, {
			name: "sum.full_adaptive",
			targetMs: 60,
			maxWarmupMs: 500,
		});
		if (full.warmup < 1)
			throw 'Smoke: expected full-adaptive warmup > 0, got ${full.warmup}';
		if (full.iterations < 1)
			throw 'Smoke: expected full-adaptive iterations >= 1, got ${full.iterations}';
		assertPositiveFiniteMs(full, "full_adaptive");
		assertNearTargetMs(full.duration.toFloat(), 60, full.iterations);

		Sys.println('name=${full.name} durationMs=${full.duration.toFloat()} iterations=${full.iterations} warmup=${full.warmup}');
	}

	/**
		Max-bound path: unstable / never-stable work must still exit via
		`maxWarmupMs` (and stay under a generous wall-time guard).
	**/
	static function assertMaxWarmupBound():Void {
		var phase = 0;
		final unstable = () -> {
			phase++;
			// Alternate heavy vs light so successive batch means never stabilize.
			final n = (phase % 2 == 0) ? 2000 : 20;
			var sum = 0;
			for (i in 0...n)
				sum += i;
			return sum;
		};

		final maxWarmupMs = 80.0;
		final wallStart = haxe.Timer.stamp();
		final r = Measure.run(unstable, {
			name: "sum.warmup_cap",
			iterations: 100,
			maxWarmupMs: maxWarmupMs,
			warmupPatience: 100,
			warmupTolerance: 0.0001,
		});
		final wallMs = (haxe.Timer.stamp() - wallStart) * 1000.0;

		if (r.warmup < 1)
			throw 'Smoke: expected capped warmup > 0, got ${r.warmup}';
		// Must terminate: wall time should not run away past the hard cap by much
		// (timed measure of 100 iters is small; leave headroom for interp noise).
		final wallCap = maxWarmupMs + 2000;
		if (wallMs > wallCap)
			throw 'Smoke: warmup did not terminate in time: wallMs=$wallMs cap=$wallCap (warmup=${r.warmup})';
		if (r.iterations != 100)
			throw 'Smoke: expected iterations 100 after capped warmup, got ${r.iterations}';

		Sys.println('name=${r.name} warmup=${r.warmup} wallMs=$wallMs (maxWarmupMs=$maxWarmupMs)');
	}

	static function assertInvalidOpts(work:() -> Int):Void {
		assertThrows("iterations < 1", () -> Measure.run(work, {iterations: 0, warmup: 1}));
		assertThrows("iterations < 1 (negative)", () -> Measure.run(work, {iterations: -1, warmup: 0}));
		assertThrows("warmup < 0", () -> Measure.run(work, {iterations: 1, warmup: -1}));
	}

	static function assertThrows(label:String, run:() -> Void):Void {
		var threw = false;
		try {
			run();
		} catch (e:Dynamic) {
			threw = true;
			final msg = Std.string(e);
			if (msg.indexOf("Measure.run") < 0)
				throw 'Smoke: $label error should mention Measure.run, got $msg';
		}
		if (!threw)
			throw 'Smoke: expected $label to throw';
	}

	static function assertPositiveFiniteMs(r:MeasureResult, label:String):Void {
		final ms = r.duration.toFloat();
		if (!Math.isFinite(ms) || !(ms > 0))
			throw 'Smoke: expected positive finite $label duration, got $ms';
	}

	static function assertNearTargetMs(actualMs:Float, targetMs:Float, iterations:Int):Void {
		final lo = targetMs * 0.5;
		final hi = targetMs * 1.5;
		if (actualMs < lo || actualMs > hi)
			throw 'Smoke: duration $actualMs ms not in [$lo, $hi] for targetMs=$targetMs (iters=$iterations)';
	}
}
