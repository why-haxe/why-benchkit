package why.benchkit;

typedef CompareReport = {
	final base:String;
	final head:String;
	final threshold:Float;
	final entries:Array<CompareEntry>;
}
