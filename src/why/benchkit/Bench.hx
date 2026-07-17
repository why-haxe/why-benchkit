package why.benchkit;

import haxe.Timer;

/**
	Public entry for why-benchkit micro-benchmarks.
**/
class Bench {
	static inline final DEFAULT_ITERATIONS:Int = 1000;
	static inline final DEFAULT_WARMUP:Int = 10;

	function new() {}

	/**
		Measure `fn` for `opts.iterations` timed runs after `opts.warmup` untimed runs.
		Return a value from `fn` so the framework can sink it and prevent DCE.
	**/
	public static function measure<T>(fn:() -> T, ?opts:MeasureOptions):MeasureResult {
		final iterations = opts?.iterations ?? DEFAULT_ITERATIONS;
		final warmup = opts?.warmup ?? DEFAULT_WARMUP;

		if (iterations < 1)
			throw "why.benchkit.Bench.measure: iterations must be >= 1";
		if (warmup < 0)
			throw "why.benchkit.Bench.measure: warmup must be >= 0";

		for (_ in 0...warmup)
			Sink.blackHole(fn());

		final start = Timer.stamp();
		for (_ in 0...iterations)
			Sink.blackHole(fn());
		final totalSeconds = Timer.stamp() - start;
		final totalMs = totalSeconds * 1000.0;
		// Zero-duration can happen with coarse timers + tiny work; report Infinity rather than NaN.
		final opsPerSec = if (totalSeconds > 0) iterations / totalSeconds else Math.POSITIVE_INFINITY;

		return {
			iterations: iterations,
			warmup: warmup,
			totalSeconds: totalSeconds,
			totalMs: totalMs,
			opsPerSec: opsPerSec,
		};
	}
}
