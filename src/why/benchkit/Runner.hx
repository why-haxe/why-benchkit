package why.benchkit;

import travix.Logger;

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
		Loads reporters via `Config`, builds `BenchmarkResult`, reports, then exits.
	**/
	public static macro function run(suites:Array<Dynamic>):Void;

	/**
		Load reporters via `Config` (fail-fast), then exit on error.
		Emitted by the `run` macro — not part of the public suite DSL.
	**/
	@:noCompletion
	public static function loadReporters():Array<Reporter> {
		try {
			return Config.createReporters();
		} catch (e:Dynamic) {
			Logger.println('why.benchkit: error: ${Std.string(e)}');
			Logger.exit(1);
			return [];
		}
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
