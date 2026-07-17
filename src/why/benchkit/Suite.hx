package why.benchkit;

import travix.Logger;

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
		optionally write `--json <path>` from process args, then exit via `Logger.exit`
		(unless `opts.exit` is `false`).
	**/
	public function run(?opts:SuiteRunOptions):SuiteResult {
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

		var exitCode = 0;
		try {
			final flags = ProcessFlags.parse(opts?.args ?? ProcessArgs.get());
			if (flags.jsonPath != null)
				JsonWriter.write(flags.jsonPath, SuiteJson.stringify(suiteResult));
		} catch (e:Dynamic) {
			Logger.println('why.benchkit: error: ${Std.string(e)}');
			exitCode = 1;
		}

		if (opts?.exit ?? true)
			Logger.exit(exitCode);

		if (exitCode != 0)
			throw 'why.benchkit: suite run failed (exit $exitCode)';

		return suiteResult;
	}
}

private typedef RegisteredCase = {
	final name:String;
	final fn:() -> Any;
	final iterations:Int;
	final warmup:Int;
}
