package why.benchkit;

/**
	Reports a completed suite document (console, JSON file, etc.).
	Used by standalone `Suite.run` and by the host after result handoff.
**/
interface Reporter {
	function report(doc:SuiteJsonDocument):Void;
}
