package why.benchkit;

/**
	Options for `Measure.run`.

	When `iterations` and/or `warmup` are omitted, measurement uses adaptive mode
	(see `Measure.run`). Explicit values always win. Adaptive knobs below only
	apply when the corresponding adaptive path is active.
**/
typedef MeasureOptions = {
	/** Measurement name (defaults to empty when omitted). */
	?name:String,
	/** Timed iterations after warmup. Omitted → time-budgeted count. */
	?iterations:Int,
	/** Untimed iterations run before measuring. Omitted → adaptive warmup. */
	?warmup:Int,

	/**
		Timed-window budget in milliseconds when `iterations` is omitted.
		Default: `500`.
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
