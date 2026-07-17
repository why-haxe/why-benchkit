package why.benchkit;

import haxe.Timer;

/**
	Shared measure loop used by `Bench.measure` and `Suite.run`.
**/
class Measure {
	public static inline final DEFAULT_ITERATIONS:Int = 1000;
	public static inline final DEFAULT_WARMUP:Int = 10;

	function new() {}

	public static function run<T>(fn:() -> T, ?opts:MeasureOptions):MeasureResult {
		final iterations = opts?.iterations ?? DEFAULT_ITERATIONS;
		final warmup = opts?.warmup ?? DEFAULT_WARMUP;

		if (iterations < 1)
			throw "why.benchkit.Measure.run: iterations must be >= 1";
		if (warmup < 0)
			throw "why.benchkit.Measure.run: warmup must be >= 0";

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
