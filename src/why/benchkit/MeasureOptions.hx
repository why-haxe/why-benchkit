package why.benchkit;

/**
	Options for `Bench.measure` / per-bench overrides.
**/
typedef MeasureOptions = {
	/** Measurement name (defaults to empty when omitted). */
	?name:String,
	/** Timed iterations after warmup. */
	?iterations:Int,
	/** Untimed iterations run before measuring. */
	?warmup:Int,
}
