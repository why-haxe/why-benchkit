package why.benchkit;

/**
	One named case from `Suite.run`.
	Fields align with the suite JSON `results[]` entry shape.
**/
typedef BenchCaseResult = {
	final name:String;
	final iterations:Int;
	final warmup:Int;
	final totalSeconds:Float;
	final totalMs:Float;
	final opsPerSec:Float;
}
