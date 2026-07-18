package why.benchkit;

import why.unit.time.Millisecond;

/**
	Timing result for one named measurement.
**/
typedef MeasureResult = {
	final name:String;
	final duration:Millisecond;
}
