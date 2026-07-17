package why.benchkit;

/**
	Timing result from `Bench.measure`.
	Fields align with the suite JSON shape (`totalMs`, `opsPerSec`, `iterations`, `warmup`).
**/
typedef MeasureResult = {
	final iterations:Int;
	final warmup:Int;
	final totalSeconds:Float;
	final totalMs:Float;
	final opsPerSec:Float;
}
