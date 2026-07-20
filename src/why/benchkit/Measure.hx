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

	When `iterations` is omitted, a short probe after warmup chooses a count so
	the timed loop lasts ~`targetMs`. Adaptive warmup (omitted `warmup`) still
	uses a temporary fixed fallback (`STUB_WARMUP`) until Chunk 3.
**/
class Measure {
	static inline final DEFAULT_TARGET_MS:Float = 500;
	static inline final DEFAULT_MIN_ITERATIONS:Int = 1;
	static inline final DEFAULT_MAX_ITERATIONS:Int = 1_000_000_000;
	/** Minimum probe wall time (ms) before trusting ms-per-iter. */
	static inline final MIN_PROBE_MS:Float = 1.0;

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
				runTimeBudgeted(fn, name, warmupOpt, opts);
			case [false, false]:
				// Adaptive warmup still stubbed; iterations are time-budgeted.
				runTimeBudgeted(fn, name, STUB_WARMUP, opts);
		};
	}

	/**
		Fixed warmup + fixed timed iterations.
		Preserves pre-adaptive behavior when both opts are set.
	**/
	static function runFixed<T>(fn:() -> T, name:String, iterations:Int, warmup:Int):MeasureResult {
		warmupLoop(fn, warmup);
		return timedMeasure(fn, name, iterations, warmup);
	}

	/**
		Fixed (or stub) warmup, then calibrate iteration count to ~`targetMs`
		and run a single contiguous timed loop.
	**/
	static function runTimeBudgeted<T>(
		fn:() -> T,
		name:String,
		warmup:Int,
		opts:Null<MeasureOptions>
	):MeasureResult {
		warmupLoop(fn, warmup);

		final targetMs = opts?.targetMs ?? DEFAULT_TARGET_MS;
		final minIterations = opts?.minIterations ?? DEFAULT_MIN_ITERATIONS;
		final maxIterations = opts?.maxIterations ?? DEFAULT_MAX_ITERATIONS;
		final iterations = calibrateIterations(fn, targetMs, minIterations, maxIterations);

		return timedMeasure(fn, name, iterations, warmup);
	}

	static function warmupLoop<T>(fn:() -> T, warmup:Int):Void {
		for (_ in 0...warmup)
			Sink.blackHole(fn());
	}

	static function timedMeasure<T>(
		fn:() -> T,
		name:String,
		iterations:Int,
		warmup:Int
	):MeasureResult {
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

	/**
		Short timed probe after warmup: grow the batch until wall time is
		measurable, then `ceil(targetMs / msPerIter)` clamped to
		`[minIterations, maxIterations]`. Zero / non-finite duration → `maxIterations`.
	**/
	static function calibrateIterations<T>(
		fn:() -> T,
		targetMs:Float,
		minIterations:Int,
		maxIterations:Int
	):Int {
		if (!(targetMs > 0) || !Math.isFinite(targetMs))
			return clampInt(minIterations, minIterations, maxIterations);
		if (maxIterations < minIterations)
			return minIterations;

		var batch = 1;
		var elapsedMs = 0.0;

		while (true) {
			elapsedMs = timeBatch(fn, batch);
			if (elapsedMs >= MIN_PROBE_MS || batch >= maxIterations)
				break;
			final next = batch > Math.floor(maxIterations / 2) ? maxIterations : batch * 2;
			if (next == batch)
				break;
			batch = next;
		}

		if (!(elapsedMs > 0) || !Math.isFinite(elapsedMs))
			return maxIterations;

		final msPerIter = elapsedMs / batch;
		if (!(msPerIter > 0) || !Math.isFinite(msPerIter))
			return maxIterations;

		final estimated = targetMs / msPerIter;
		if (!Math.isFinite(estimated) || estimated >= maxIterations)
			return maxIterations;

		return clampInt(Std.int(Math.ceil(estimated)), minIterations, maxIterations);
	}

	static function timeBatch<T>(fn:() -> T, count:Int):Float {
		final start = Timer.stamp();
		for (_ in 0...count)
			Sink.blackHole(fn());
		return (Timer.stamp() - start) * 1000.0;
	}

	static function clampInt(value:Int, min:Int, max:Int):Int {
		if (value < min)
			return min;
		if (value > max)
			return max;
		return value;
	}
}
