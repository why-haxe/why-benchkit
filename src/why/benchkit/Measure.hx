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
	the timed loop lasts ~`targetMs`. When `warmup` is omitted, batches run
	until successive batch means stabilize (or `maxWarmupMs` / iteration caps).

	After warmup and iteration resolution, the timed loop runs `sampleCount`
	times (default **5**). `samples` holds each loop’s wall time; `duration`
	is their arithmetic mean.

	All four modes are fully wired (no stubs): adaptive paths use
	`doAdaptiveWarmup` / `calibrateIterations`; explicit values always win.
**/
class Measure {
	static inline final DEFAULT_TARGET_MS:Float = 150;
	static inline final DEFAULT_SAMPLE_COUNT:Int = 5;
	static inline final DEFAULT_MIN_ITERATIONS:Int = 1;
	static inline final DEFAULT_MAX_ITERATIONS:Int = 1_000_000_000;
	static inline final DEFAULT_WARMUP_TOLERANCE:Float = 0.02;
	static inline final DEFAULT_WARMUP_PATIENCE:Int = 3;
	static inline final DEFAULT_MAX_WARMUP_MS:Float = 3000;

	/** Minimum batches before stability may stop adaptive warmup. */
	static inline final MIN_WARMUP_BATCHES:Int = 2;

	/** Minimum probe / batch wall time (ms) before trusting ms-per-iter. */
	static inline final MIN_PROBE_MS:Float = 1.0;

	function new() {}

	public static function run<T>(fn:() -> T, ?opts:MeasureOptions):MeasureResult {
		final sampleCount = resolveSampleCount(opts);

		var warmup = opts?.warmup;
		var iterations = opts?.iterations;

		switch warmup {
			case null:
				warmup = doAdaptiveWarmup(fn, opts);
			case v if (v < 0):
				throw "why.benchkit.Measure.run: warmup must be >= 0";
			case v:
				doWarmup(fn, v);
		}

		// Resolve iterations once (fixed or time-budgeted calibration), then reuse
		// that count for every sample. Calibration probes are outside `samples`;
		// v1 does not discard the first sample — sample[0] may still see residual
		// JIT/GC effects after probes.
		switch iterations {
			case null:
				iterations = calibrateIterations( //
					fn, //
					opts?.targetMs ?? DEFAULT_TARGET_MS, //
					opts?.minIterations ?? DEFAULT_MIN_ITERATIONS, //
					opts?.maxIterations ?? DEFAULT_MAX_ITERATIONS //
				);
			case v if (v < 1):
				throw "why.benchkit.Measure.run: iterations must be >= 1";
			case _:
		}

		final samples = [for (_ in 0...sampleCount) doMeasure(fn, iterations)];
		final duration = meanMs(samples);

		return {
			name: opts?.name ?? "",
			duration: duration,
			iterations: iterations,
			warmup: warmup,
			samples: samples,
		}
	}

	static function resolveSampleCount(opts:Null<MeasureOptions>):Int {
		final n = opts?.sampleCount ?? DEFAULT_SAMPLE_COUNT;
		if (n < 1)
			throw "why.benchkit.Measure.run: sampleCount must be >= 1";
		return n;
	}

	/** Arithmetic mean of one or more sample durations. */
	static function meanMs(samples:Array<Millisecond>):Millisecond {
		var sum = new Millisecond(0);
		for (s in samples)
			sum = sum + s;
		return sum / samples.length;
	}

	static function doWarmup<T>(fn:() -> T, warmup:Int):Void {
		for (_ in 0...warmup)
			Sink.blackHole(fn());
	}

	/**
		Adaptive warmup: run timed batches until successive per-iter means stay
		within `warmupTolerance` for `warmupPatience` consecutive comparisons,
		after at least `MIN_WARMUP_BATCHES`. Batches faster than `MIN_PROBE_MS`
		are grown (not counted toward patience). Always terminates via
		`maxWarmupMs` and/or a total-iteration cap (`maxIterations`).
		Returns total warmup iterations actually run.
	**/
	static function doAdaptiveWarmup<T>(fn:() -> T, opts:Null<MeasureOptions>):Int {
		final tolerance = opts?.warmupTolerance ?? DEFAULT_WARMUP_TOLERANCE;
		final patience = Std.int(Math.max(1, opts?.warmupPatience ?? DEFAULT_WARMUP_PATIENCE));
		final maxWarmupMs = opts?.maxWarmupMs ?? DEFAULT_MAX_WARMUP_MS;
		final maxIterations = opts?.maxIterations ?? DEFAULT_MAX_ITERATIONS;

		var totalIterations = 0;
		var batchSize = 1;
		var batches = 0;
		var stableCount = 0;
		var prevMean:Null<Float> = null;
		final start = Timer.stamp();

		while (true) {
			final elapsedMs = (Timer.stamp() - start) * 1000.0;

			if (totalIterations >= maxIterations)
				break;
			// Hard stop: always terminate once at least one batch ran.
			if (batches >= 1 && elapsedMs >= maxWarmupMs)
				break;

			final remaining = maxIterations - totalIterations;
			if (remaining < 1)
				break;
			if (batchSize > remaining)
				batchSize = remaining;

			final batchMs = timeBatch(fn, batchSize);
			totalIterations += batchSize;
			batches++;

			// Only trust means from batches that meet MIN_PROBE_MS; faster batches
			// grow until measurable so patience cannot stop on timer noise.
			if (batchMs < MIN_PROBE_MS) {
				stableCount = 0;
				prevMean = null;
				final afterRemaining = maxIterations - totalIterations;
				if (afterRemaining > batchSize) {
					final next = batchSize > Math.floor(afterRemaining / 2) ? afterRemaining : batchSize * 2;
					batchSize = next < 1 ? 1 : next;
				}
			} else {
				final mean = batchMs / batchSize;
				if (prevMean != null && isPositiveFinite(prevMean) && isPositiveFinite(mean)) {
					final relChange = Math.abs(mean - prevMean) / prevMean;
					if (relChange <= tolerance) {
						stableCount++;
						if (batches >= MIN_WARMUP_BATCHES && stableCount >= patience)
							break;
					} else {
						stableCount = 0;
					}
				} else {
					stableCount = 0;
				}
				prevMean = mean;
			}

			// Re-check hard stop after the batch (wall clock advanced).
			final afterMs = (Timer.stamp() - start) * 1000.0;
			if (afterMs >= maxWarmupMs)
				break;
		}

		return totalIterations;
	}

	static function doMeasure<T>(fn:() -> T, iterations:Int):Millisecond {
		final start = Timer.stamp();
		for (_ in 0...iterations)
			Sink.blackHole(fn());
		return new Millisecond((Timer.stamp() - start) * 1000.0);
	}

	/**
		Short timed probe after warmup: grow the batch until wall time is
		measurable, then `ceil(targetMs / msPerIter)` clamped to
		`[minIterations, maxIterations]`. Zero / non-finite duration → `maxIterations`.
		Probes are untimed extras before the sample loop (not recorded in `samples`).
	**/
	static function calibrateIterations<T>(fn:() -> T, targetMs:Float, minIterations:Int, maxIterations:Int):Int {
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

	static function isPositiveFinite(value:Float):Bool {
		return value > 0 && Math.isFinite(value);
	}

	static function clampInt(value:Int, min:Int, max:Int):Int {
		if (value < min)
			return min;
		if (value > max)
			return max;
		return value;
	}
}
