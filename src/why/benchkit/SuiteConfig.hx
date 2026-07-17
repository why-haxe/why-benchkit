package why.benchkit;

/**
	Configuration for `Bench.suite`.
	`warmup` / `iterations` are suite defaults; per-bench opts override them.
**/
typedef SuiteConfig = {
	/** Suite name used in console summary and (later) JSON. */
	name:String,
	/** Default timed iterations for benches that omit `opts.iterations`. */
	?iterations:Int,
	/** Default warmup iterations for benches that omit `opts.warmup`. */
	?warmup:Int,
}
