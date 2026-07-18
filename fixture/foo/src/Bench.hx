package;

class Bench {
	public static function main() {
		final suite = why.benchkit.Bench.suite({
			name: "my_lib",
			warmup: 50,
			iterations: 10_000,
		});

		suite.bench("op.name", () -> doWork(), {
			iterations: 1_000_000,
			warmup: 100,
		});

		suite.bench("op.hot", () -> hot(), {
			iterations: 1_000_000,
			warmup: 100,
		});

		suite.run(); // always prints a summary; honors --json / host JSON env
	}

	static function doWork() {
		return haxe.Json.parse('{"foo": "bar"}');
	}

	static function hot() {
		return haxe.Json.stringify({"foo": "bar"});
	}
}
