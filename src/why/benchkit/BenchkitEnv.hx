package why.benchkit;

/**
	Shared env keys between the suite process and the host runner.
**/
class BenchkitEnv {
	function new() {}

	/**
		JSON reporter config for the suite process (`Config.load`).
		Shape: `{ "target": "node", "reporters": [{ "name": "console" }, { "name": "json", "outputDir": "..." }] }`.
		Root `target` is required when a json reporter is present.
		Browser runs use `window.why.benchkit` instead (same shape).
	**/
	public static final CONFIG:String = 'WHY_BENCHKIT_CONFIG';
}
