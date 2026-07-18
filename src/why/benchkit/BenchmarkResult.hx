package why.benchkit;

/**
	Finished benchmark run: compile-time metadata + suite results.
**/
typedef BenchmarkResult = {
	final haxeVersion:String;
	final target:String;
	final timestamp:Float;
	final results:Array<SuiteResult>;
	final commitHash:String;
}
