package why.benchkit;

/**
	One entry in the suite JSON `results` array (Design reference shape).
**/
typedef SuiteJsonCase = {
	final name:String;
	final iterations:Int;
	final warmup:Int;
	final totalMs:Float;
	final opsPerSec:Float;
}
