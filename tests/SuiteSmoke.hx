import why.benchkit.Runner;

/**
	Runner DSL smoke on interp (`@:name` / `@:warmup` / `@:iterations`).
	Usage: haxe suite.hxml
**/
class SuiteSmoke {
	static function main():Void {
		Runner.run([
			new SuiteSmokeCases(),
		]);
	}
}

@:name("suite_smoke")
class SuiteSmokeCases {
	public function new() {}

	@:name("sum.loop")
	@:warmup(50)
	@:iterations(5000)
	public function sumLoop():Int {
		var sum = 0;
		for (i in 0...100)
			sum += i;
		return sum;
	}

	@:name("sum.hot")
	@:warmup(100)
	@:iterations(20000)
	public function sumHot():Int {
		var sum = 0;
		for (i in 0...50)
			sum += i;
		return sum;
	}

	/** Iterations override only; warmup uses Measure default. */
	@:name("sum.partial")
	@:iterations(8000)
	public function sumPartial():Int {
		var sum = 0;
		for (i in 0...20)
			sum += i;
		return sum;
	}
}
