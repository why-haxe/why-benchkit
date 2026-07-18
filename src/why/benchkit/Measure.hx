package why.benchkit;

import haxe.Timer;
import why.unit.time.Millisecond;

/**
	Shared measure loop used by `Bench.measure` and `Suite.run`.
**/
class Measure {
	public static inline final DEFAULT_ITERATIONS:Int = 1000;
	public static inline final DEFAULT_WARMUP:Int = 10;

	function new() {}

	public static function run<T>(fn:() -> T, ?opts:MeasureOptions):MeasureResult {
		final name = opts?.name ?? "";
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
		final totalMs = (Timer.stamp() - start) * 1000.0;

		return {
			name: name,
			duration: new Millisecond(totalMs),
		};
	}
}
