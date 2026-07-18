package why.benchkit;

/**
	Top-level suite JSON document written for `--json <path>` / host handoff.
**/
typedef SuiteJsonDocument = {
	final suite:String;
	final target:String;
	final haxeVersion:String;
	final timestamp:String;
	final results:Array<SuiteJsonCase>;
}
