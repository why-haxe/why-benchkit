package why.benchkit;

/**
	Named micro-benchmark suite: register cases with `bench`, run with `run`.
**/
class Suite {
	final name:String;
	final defaultIterations:Int;
	final defaultWarmup:Int;
	final cases:Array<RegisteredCase>;

	/**
		Prefer `Bench.suite(config)` over constructing directly.
	**/
	@:allow(why.benchkit.Bench)
	function new(config:SuiteConfig) {
		this.name = config.name;
		this.defaultIterations = config.iterations ?? Measure.DEFAULT_ITERATIONS;
		this.defaultWarmup = config.warmup ?? Measure.DEFAULT_WARMUP;
		this.cases = [];
	}

	/**
		Register a named benchmark. Per-bench `opts` override suite defaults.
		Resolved iterations/warmup are snapshotted at registration.
		Return a value from `fn` so the framework can sink it and prevent DCE.
	**/
	public function bench<T>(name:String, fn:() -> T, ?opts:MeasureOptions):Suite {
		cases.push({
			name: name,
			fn: () -> (fn() : Any),
			iterations: opts?.iterations ?? defaultIterations,
			warmup: opts?.warmup ?? defaultWarmup,
		});
		return this;
	}

	/**
		Measure each registered case, print a console summary via `travix.Logger`,
		and return in-memory results for later JSON emission.
	**/
	public function run():SuiteResult {
		final results:Array<BenchCaseResult> = [];
		for (c in cases) {
			final m = Measure.run(c.fn, {
				iterations: c.iterations,
				warmup: c.warmup,
			});
			results.push({
				name: c.name,
				iterations: m.iterations,
				warmup: m.warmup,
				totalSeconds: m.totalSeconds,
				totalMs: m.totalMs,
				opsPerSec: m.opsPerSec,
			});
		}
		final suiteResult:SuiteResult = {
			name: name,
			results: results,
		};
		ConsoleReporter.report(suiteResult);
		return suiteResult;
	}
}

private typedef RegisteredCase = {
	final name:String;
	final fn:() -> Any;
	final iterations:Int;
	final warmup:Int;
}
