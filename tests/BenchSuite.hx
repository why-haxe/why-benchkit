import why.benchkit.Runner;

/**
	Default suite entry for travix / `why-benchkit run` (`bench.hxml`).
	Keep iterations low so host multi-target smoke stays quick.
**/
class BenchSuite {
	static function main():Void {
		Runner.run([
			new WhyBenchkitSuite(),
		]);
	}
}

@:name("why_benchkit")
class WhyBenchkitSuite {
	public function new() {}

	@:name("sum.loop")
	@:warmup(10)
	@:iterations(1000)
	public function sumLoop():Int {
		var sum = 0;
		for (i in 0...100)
			sum += i;
		return sum;
	}
}
