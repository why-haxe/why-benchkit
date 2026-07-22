package why.benchkit;

enum abstract CompareVerdict(String) to String {
	var Improved = "improved";
	var Degraded = "degraded";
	var Unchanged = "unchanged";
	var MissingBase = "missing_base";
	var MissingHead = "missing_head";
}
