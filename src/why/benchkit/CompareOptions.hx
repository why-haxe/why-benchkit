package why.benchkit;

typedef CompareOptions = {
	final base:String;
	final head:String;
	/** Relative ops/sec threshold for major change (default `Compare.DEFAULT_THRESHOLD` = 0.10). */
	final ?threshold:Float;
}
