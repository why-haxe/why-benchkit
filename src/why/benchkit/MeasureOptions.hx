package why.benchkit;

/**
	Options for `Measure.run`.

	When `iterations` and/or `warmup` are omitted, measurement uses adaptive mode
	(see `Measure.run` four-mode matrix). Explicit values always win. Adaptive
	knobs below only apply when the corresponding adaptive path is active.

	After warmup and iteration resolution, `sampleCount` independent timed loops
	run; `MeasureResult.samples` holds each, and `duration` is their mean.

	When called via `Runner`, host `BenchkitConfig.sampleCount` is merged into
	opts first (explicit `sampleCount` wins). Direct `Measure.run` callers that
	omit `sampleCount` still get the library default of `5`.
**/
typedef MeasureOptions = {
	/** Measurement name (defaults to empty when omitted). */
	?name:String,
	/** Timed iterations after warmup. Omitted → time-budgeted count. */
	?iterations:Int,
	/** Untimed iterations run before measuring. Omitted → adaptive warmup. */
	?warmup:Int,

	/**
		Independent timed loops after warmup (each with `iterations` runs).
		Default: `5` when omitted here and no host config applies.
		Must be >= 1. Precedence when using `Runner`: explicit opts >
		host `BenchkitConfig.sampleCount` > `5`.
	**/
	?sampleCount:Int,

	/**
		Timed-window budget in milliseconds when `iterations` is omitted.
		Default: `150`.
	**/
	?targetMs:Float,
	/**
		Lower clamp for calibrated iteration count.
		Default: `1`.
	**/
	?minIterations:Int,
	/**
		Upper clamp for calibrated iteration count.
		Default: `1_000_000_000`.
	**/
	?maxIterations:Int,
	/**
		Relative change tolerance for adaptive warmup batch means (e.g. `0.02` = 2%).
		Default: `0.02`.
	**/
	?warmupTolerance:Float,
	/**
		Consecutive stable batches required to stop adaptive warmup.
		Default: `3`.
	**/
	?warmupPatience:Int,
	/**
		Hard cap on adaptive warmup wall time in milliseconds.
		Default: `3000`.
	**/
	?maxWarmupMs:Float,
}
