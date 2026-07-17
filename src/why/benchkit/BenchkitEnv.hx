package why.benchkit;

/**
	Shared env keys between the suite process and the host runner.
**/
class BenchkitEnv {
	function new() {}

	/**
		Absolute path for suite JSON when the host uses `--json-dir`.
		Suite: `ProcessFlags` reads this if `--json` is absent from argv.
		Host: set per target before travix `buildAndRun`.
		Browser `js`: packaged hooks also derive `window.benchkitArgs` from this.
	**/
	public static final JSON_PATH:String = 'WHY_BENCHKIT_JSON';
}
