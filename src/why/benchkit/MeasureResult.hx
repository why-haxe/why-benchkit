package why.benchkit;

import why.unit.time.Millisecond;

/**
	Timing result for one named measurement.
	`samples` are independent timed loops (each with `iterations` runs).
	`duration` is the reported aggregate (typically mean of `samples`).
**/
typedef MeasureResult = {
	final name:String;

	/** Headline duration for reporters / charts (aggregate of `samples`). */
	final duration:Millisecond;

	/** Iterations in each timed sample (same for every sample). */
	final iterations:Int;

	/** Warmup iterations run before sampling (once, not per sample). */
	final warmup:Int;

	/** Wall times of each timed loop; length >= 1. */
	final ?samples:Array<Millisecond>;
}
