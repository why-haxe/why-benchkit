package why.benchkit;

/**
	Reports a completed benchmark result (console, JSON file, etc.).
	Used by standalone `Suite.run` and by the host after result handoff.
**/
interface Reporter {
	function report(result:BenchmarkResult):Void;
}
