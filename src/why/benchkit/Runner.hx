package why.benchkit;

import travix.Logger;
import why.benchkit.Config.BenchkitConfig;

/**
	Suite entry: macro discovers public measure methods, runs them, reports, exits.

	```haxe
	why.benchkit.Runner.run([
		new MySuite()
	]);
	```
**/
class Runner {
	function new() {}

	/**
		Run suite instances from an **array literal** so the macro can discover each
		suite type’s public instance methods (`@:name` / `@:warmup` / `@:iterations`).
		Loads config via `Config`, builds `BenchmarkResult`, reports, then exits.
	**/
	public static macro function run(suites:Array<Dynamic>):Void;

	/**
		Load `BenchkitConfig` (fail-fast), then exit on error.
		Emitted by the `run` macro — not part of the public suite DSL.
	**/
	@:noCompletion
	public static function loadConfig():BenchkitConfig {
		try {
			return Config.load();
		} catch (e:Dynamic) {
			Logger.println('why.benchkit: error: ${Std.string(e)}');
			Logger.exit(1);
			return {reporters: []};
		}
	}

	/**
		Build reporters from an already-loaded config (fail-fast), then exit on error.
		Emitted by the `run` macro — not part of the public suite DSL.
	**/
	@:noCompletion
	public static function reportersFromConfig(config:BenchkitConfig):Array<Reporter> {
		try {
			return Config.reportersFrom(config);
		} catch (e:Dynamic) {
			Logger.println('why.benchkit: error: ${Std.string(e)}');
			Logger.exit(1);
			return [];
		}
	}

	/**
		Fill `sampleCount` from host config when measure opts omit it.

		Precedence: explicit `MeasureOptions.sampleCount` (incl. suite/macro opts)
		> host `BenchkitConfig.sampleCount` > default `5` (inside `Measure.run`).
	**/
	@:noCompletion
	public static function applyHostSampleCount(opts:MeasureOptions, ?hostSampleCount:Null<Int>):MeasureOptions {
		if (opts.sampleCount != null || hostSampleCount == null)
			return opts;
		final merged:Dynamic = Reflect.copy(opts);
		merged.sampleCount = hostSampleCount;
		return merged;
	}

	/**
		Assemble `BenchmarkResult`, invoke `reporters`, then exit.
		Emitted by the `run` macro — not part of the public suite DSL.
	**/
	@:noCompletion
	public static function finish(suiteResults:Array<SuiteResult>, reporters:Array<Reporter>):Void {
		final doc:BenchmarkResult = {
			haxeVersion: BenchmarkMeta.haxeVersion(),
			target: BenchmarkMeta.target(),
			timestamp: Date.now().getTime(),
			results: suiteResults,
			commitHash: BenchmarkMeta.gitHash(),
		};

		var exitCode = 0;
		try {
			for (r in reporters)
				r.report(doc);
		} catch (e:Dynamic) {
			Logger.println('why.benchkit: error: ${Std.string(e)}');
			exitCode = 1;
		}

		Logger.exit(exitCode);
	}
}
