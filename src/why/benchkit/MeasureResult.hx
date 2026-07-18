package why.benchkit;

import why.unit.time.*;

/**
	Timing result from `Bench.measure`.
	Fields align with the suite JSON shape (`totalMs`, `opsPerSec`, `iterations`, `warmup`).
**/
typedef MeasureResult = {
	final iterations:Int;
	final warmup:Int;
	final duration:Millisecond;
	final opsPerSec:Float;
}
