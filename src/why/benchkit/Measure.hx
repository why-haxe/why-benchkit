package why.benchkit;

import haxe.Timer;
import why.unit.time.Millisecond;

/**
	Shared measure loop used by `Runner` (and callable directly).

	Mode selection when `iterations` / `warmup` are set or omitted:

	| iterations | warmup | Behavior |
	| --- | --- | --- |
	| omitted | omitted | Full adaptive (warmup + time-budgeted measure) |
	| set | omitted | Adaptive warmup; then exactly `iterations` timed runs |
	| omitted | set | Fixed warmup; then time-budgeted measurement |
	| set | set | Fixed warmup + fixed iterations |

	Adaptive algorithms land in later chunks; omitted fields currently use a
	temporary fixed fallback (`STUB_ITERATIONS` / `STUB_WARMUP`).
**/
class Measure {
	/** Temporary until Chunk 2 replaces time-budgeted calibration. */
	static inline final STUB_ITERATIONS:Int = 1000;
	/** Temporary until Chunk 3 replaces adaptive warmup. */
	static inline final STUB_WARMUP:Int = 10;

	function new() {}

	public static function run<T>(fn:() -> T, ?opts:MeasureOptions):MeasureResult {
		final name = opts?.name ?? "";
		final iterationsOpt = opts?.iterations;
		final warmupOpt = opts?.warmup;

		if (iterationsOpt != null && iterationsOpt < 1)
			throw "why.benchkit.Measure.run: iterations must be >= 1";
		if (warmupOpt != null && warmupOpt < 0)
			throw "why.benchkit.Measure.run: warmup must be >= 0";

		return switch [iterationsOpt != null, warmupOpt != null] {
			case [true, true]:
				runFixed(fn, name, iterationsOpt, warmupOpt);
			case [true, false]:
				// Adaptive warmup (Chunk 3) + fixed iterations — stub warmup for now.
				runFixed(fn, name, iterationsOpt, STUB_WARMUP);
			case [false, true]:
				// Fixed warmup + time-budgeted iterations (Chunk 2) — stub iterations for now.
				runFixed(fn, name, STUB_ITERATIONS, warmupOpt);
			case [false, false]:
				// Full adaptive (Chunks 2–3) — temporary fixed path.
				runFixed(fn, name, STUB_ITERATIONS, STUB_WARMUP);
		};
	}

	/**
		Fixed warmup + fixed timed iterations.
		Preserves pre-adaptive behavior when both opts are set; also backs stubs.
	**/
	static function runFixed<T>(fn:() -> T, name:String, iterations:Int, warmup:Int):MeasureResult {
		for (_ in 0...warmup)
			Sink.blackHole(fn());

		final start = Timer.stamp();
		for (_ in 0...iterations)
			Sink.blackHole(fn());
		final totalMs = (Timer.stamp() - start) * 1000.0;

		return {
			name: name,
			duration: new Millisecond(totalMs),
			iterations: iterations,
			warmup: warmup,
		};
	}
}
