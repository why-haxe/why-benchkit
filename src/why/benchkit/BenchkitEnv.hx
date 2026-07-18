package why.benchkit;

/**
	Shared env keys between the suite process and the host runner.
**/
class BenchkitEnv {
	function new() {}

	/**
		Absolute path for suite JSON when running standalone with host-set env
		(`ProcessFlags` fallback if `--json` is absent from argv).
	**/
	public static final JSON_PATH:String = 'WHY_BENCHKIT_JSON';

	/**
		Absolute path where the suite must hand off `SuiteJsonDocument` JSON
		when driven by the host multi-target runner. When set, `Suite.run`
		skips local reporters and uses `ResultBridge.emit`.
		Browser `js`: hooks also set `window.benchkitResultPath` from this.
	**/
	public static final RESULT_PATH:String = 'WHY_BENCHKIT_RESULT';
}