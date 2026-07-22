package why.benchkit;

typedef CompareEntry = {
	final haxeVersion:String;
	final target:String;
	final suite:String;
	final measure:String;
	final ?baseOps:Float;
	final ?headOps:Float;
	/** Relative ops/sec delta; omitted when a side is missing. */
	final ?delta:Float;
	final verdict:CompareVerdict;
}
