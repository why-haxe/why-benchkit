package why.benchkit;

/**
	Public entry for why-benchkit micro-benchmarks.
**/
class Bench {
	public static inline final DEFAULT_ITERATIONS:Int = Measure.DEFAULT_ITERATIONS;
	public static inline final DEFAULT_WARMUP:Int = Measure.DEFAULT_WARMUP;

	function new() {}

	/**
		Create a named suite with optional default warmup / iterations.
	**/
	public static function suite(config:SuiteConfig):Suite {
		return new Suite(config);
	}

	/**
		Measure `fn` for `opts.iterations` timed runs after `opts.warmup` untimed runs.
		Return a value from `fn` so the framework can sink it and prevent DCE.
	**/
	public static function measure<T>(fn:() -> T, ?opts:MeasureOptions):MeasureResult {
		return Measure.run(fn, opts);
	}
}
