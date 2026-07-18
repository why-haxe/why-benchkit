package why.benchkit;

/**
	Reports a completed `BenchmarkResult` (console, JSON file, etc.).
**/
interface Reporter {
	function report(result:BenchmarkResult):Void;
}
