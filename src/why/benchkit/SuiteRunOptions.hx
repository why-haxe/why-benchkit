package why.benchkit;

/**
	Optional controls for `Suite.run`.
	Standalone reporting is driven by `Config` (`WHY_BENCHKIT_CONFIG` /
	`window.why.benchkit`), not process argv.
**/
typedef SuiteRunOptions = {
	/**
		When `false`, skip `travix.Logger.exit` so callers can keep running (tests).
		Default: `true` (suite process exits after report or host handoff).
	**/
	final ?exit:Bool;
}
