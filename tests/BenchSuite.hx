import why.benchkit.Bench;

/**
	Default suite entry for travix / `why-benchkit run` (`bench.hxml`).
	Keep iterations low so host multi-target smoke stays quick.
**/
class BenchSuite {
	static function main():Void {
		final suite = Bench.suite({
			name: "why_benchkit",
			warmup: 10,
			iterations: 1_000,
		});

		suite.bench("sum.loop", () -> {
			var sum = 0;
			for (i in 0...100)
				sum += i;
			return sum;
		});

		suite.run();
	}
}
