package why.benchkit;

/**
	Outcome of one suite: name plus its measurements.
**/
typedef SuiteResult = {
	final name:String;
	final results:Array<MeasureResult>;
}
