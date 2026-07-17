package why.benchkit;

/**
	Options for `Bench.measure` / per-bench overrides.
**/
typedef MeasureOptions = {
	/** Timed iterations after warmup. */
	?iterations:Int,
	/** Untimed iterations run before measuring. */
	?warmup:Int,
}
