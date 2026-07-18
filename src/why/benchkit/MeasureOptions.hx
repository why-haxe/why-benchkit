package why.benchkit;

/**
	Options for `Measure.run` (name, iterations, warmup).
**/
typedef MeasureOptions = {
	/** Measurement name (defaults to empty when omitted). */
	?name:String,
	/** Timed iterations after warmup. */
	?iterations:Int,
	/** Untimed iterations run before measuring. */
	?warmup:Int,
}
