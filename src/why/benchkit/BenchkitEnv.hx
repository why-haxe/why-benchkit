package why.benchkit;

/**
	Shared env keys between the suite process and the host runner.
**/
class BenchkitEnv {
	function new() {}

	/**
		JSON reporter config for the suite process (`Config.load`).
		Shape: `{ "reporters": [{ "name": "console" }, { "name": "json", "outputPath": "..." }] }`.
		Browser runs use `window.why.benchkit` instead (same shape).
	**/
	public static final CONFIG:String = 'WHY_BENCHKIT_CONFIG';

	/**
		Absolute path for suite JSON when running standalone with host-set env
		(`ProcessFlags` fallback if `--json` is absent from argv).
		Still used by `ProcessFlags` until Chunk 06 removes that path.
	**/
	public static final JSON_PATH:String = 'WHY_BENCHKIT_JSON';

	/**
		Absolute path where the suite must hand off `BenchmarkResult` JSON
		when driven by the host multi-target runner. When set, `Suite.run`
		skips local reporters and uses `ResultBridge.emit`.
		Browser `js`: hooks also set `window.benchkitResultPath` from this.
		Still used by host/ResultBridge until Chunks 06/07 switch to config inject.
	**/
	public static final RESULT_PATH:String = 'WHY_BENCHKIT_RESULT';
}
