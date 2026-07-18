package why.benchkit;

/**
	One named case from `Suite.run`.
	Fields align with the suite JSON `results[]` entry shape (plus `totalSeconds`).
**/
typedef BenchCaseResult = MeasureResult & {
	final name:String;
};
