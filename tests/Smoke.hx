import why.benchkit.Measure;

/**
	Measure-core smoke on interp: name + positive duration.
	Usage: haxe smoke.hxml
**/
class Smoke {
	static function main():Void {
		final r = Measure.run(() -> {
			var sum = 0;
			for (i in 0...100)
				sum += i;
			return sum;
		}, {
			name: "sum.loop",
			iterations: 10_000,
			warmup: 100,
		});

		if (r.name != "sum.loop")
			throw 'Smoke: unexpected name ${r.name}';
		final ms = r.duration.toFloat();
		if (!Math.isFinite(ms) || !(ms > 0))
			throw 'Smoke: expected positive finite duration, got $ms';

		Sys.println('name=${r.name} durationMs=$ms');
	}
}
