package why.benchkit;

/**
	Optional controls for `Suite.run`.
	Process CLI flags (`--json`) come from `ProcessArgs` unless `args` is set
	(`Sys.args()` on sys/node; `window.benchkitArgs` on browser `js`).
**/
typedef SuiteRunOptions = {
	/**
		When `false`, skip `travix.Logger.exit` so callers can keep running (tests).
		Default: `true` (suite process exits after summary / optional JSON).
	**/
	final ?exit:Bool;
	/**
		Override process argv for flag parsing (tests / embedding).
		Default: `ProcessArgs.get()`.
	**/
	final ?args:Array<String>;
}
