package why.benchkit;

import travix.Logger;
import why.benchkit.reporter.ConsoleReporter;
import why.benchkit.reporter.JsonReporter;

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
		Measure each registered case, then either:
		- host mode (`WHY_BENCHKIT_RESULT` set): hand off via `ResultBridge` and exit
		- standalone: run local reporters (console + optional `--json`) and exit

		Skips exit when `opts.exit` is `false` (tests / embedding).
	**/
	public function run(?opts:SuiteRunOptions):SuiteResult {
		final results:Array<MeasureResult> = [];
		for (c in cases) {
			results.push(Measure.run(c.fn, {
				name: c.name,
				iterations: c.iterations,
				warmup: c.warmup,
			}));
		}
		final suiteResult:SuiteResult = {
			name: name,
			results: results,
		};
		final doc:BenchmarkResult = {
			haxeVersion: BenchmarkMeta.haxeVersion(),
			target: BenchmarkMeta.target(),
			timestamp: BenchmarkMeta.timestampNow(),
			results: [suiteResult],
		};

		var exitCode = 0;
		try {
			if (ResultBridge.isHostMode()) {
				ResultBridge.emit(doc);
			} else {
				final reporters:Array<Reporter> = [new ConsoleReporter()];
				final flags = ProcessFlags.parse(opts?.args ?? ProcessArgs.get());
				if (flags.jsonPath != null)
					reporters.push(JsonReporter.toPath(flags.jsonPath));
				for (r in reporters)
					r.report(doc);
			}
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
