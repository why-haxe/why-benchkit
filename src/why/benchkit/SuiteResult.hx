package why.benchkit;

/**
	In-memory suite outcome from `Suite.run` (console + future JSON).
**/
typedef SuiteResult = {
	final name:String;
	final results:Array<BenchCaseResult>;
}
