import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import why.benchkit.Bench;
import why.benchkit.ProcessFlags;
import why.benchkit.SuiteJson;
import why.benchkit.UtcIso;

/**
	Phase 3 smoke: `--json` parsing, serialization shape, Suite.run write on interp.
	Usage: haxe json.hxml
**/
class JsonSmoke {
	static function main():Void {
		final flags = ProcessFlags.parse(["--json", "out/example.json"]);
		if (flags.jsonPath != "out/example.json")
			throw 'JsonSmoke: expected jsonPath out/example.json, got ${flags.jsonPath}';

		var threw = false;
		try {
			ProcessFlags.parse(["--json"]);
		} catch (e:Dynamic) {
			threw = true;
		}
		if (!threw)
			throw "JsonSmoke: expected --json without path to throw";

		threw = false;
		try {
			ProcessFlags.parse(["--json", ""]);
		} catch (e:Dynamic) {
			threw = true;
		}
		if (!threw)
			throw "JsonSmoke: expected empty --json path to throw";

		final none = ProcessFlags.parse(["--verbose", "x"]);
		if (none.jsonPath != null)
			throw "JsonSmoke: expected null jsonPath when --json absent";

		final ts = UtcIso.format(Date.fromTime(0));
		if (ts != "1970-01-01T00:00:00Z")
			throw 'JsonSmoke: UtcIso epoch expected 1970-01-01T00:00:00Z, got $ts';

		if (!FileSystem.exists("dump"))
			FileSystem.createDirectory("dump");
		final outPath = "dump/json_smoke.json";
		if (FileSystem.exists(outPath))
			FileSystem.deleteFile(outPath);

		final suite = Bench.suite({
			name: "json_smoke",
			warmup: 5,
			iterations: 200,
		});
		suite.bench("nop", () -> 1);

		// Drive Suite.run's --json path via args override (avoids relying on Sys.args under --interp).
		final result = suite.run({
			exit: false,
			args: ["--json", outPath],
		});

		if (!FileSystem.exists(outPath))
			throw 'JsonSmoke: Suite.run did not write $outPath';

		final roundtrip:Dynamic = Json.parse(File.getContent(outPath));
		if (roundtrip.suite != "json_smoke")
			throw 'JsonSmoke: file suite field ${roundtrip.suite}';
		if (roundtrip.target != "interp")
			throw 'JsonSmoke: expected target interp, got ${roundtrip.target}';
		if (roundtrip.haxeVersion == null || roundtrip.haxeVersion == "" || roundtrip.haxeVersion == "unknown")
			throw 'JsonSmoke: bad haxeVersion ${roundtrip.haxeVersion}';
		if (roundtrip.results.length != 1)
			throw 'JsonSmoke: results length ${roundtrip.results.length}';
		final r0 = roundtrip.results[0];
		if (r0.name != "nop" || r0.iterations != 200 || r0.warmup != 5)
			throw 'JsonSmoke: bad result row ${r0.name}/${r0.iterations}/${r0.warmup}';
		if (!Math.isFinite(r0.totalMs) || !Math.isFinite(r0.opsPerSec))
			throw "JsonSmoke: non-finite timing in JSON case";
		// Design shape: no totalSeconds in JSON results.
		if (Reflect.hasField(r0, "totalSeconds"))
			throw "JsonSmoke: JSON should omit totalSeconds";
		if (roundtrip.timestamp == null || !~/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.match(roundtrip.timestamp))
			throw 'JsonSmoke: bad timestamp ${roundtrip.timestamp}';

		final doc = SuiteJson.fromSuiteResult(result, "2026-07-17T12:00:00Z");
		if (doc.timestamp != "2026-07-17T12:00:00Z")
			throw 'JsonSmoke: fixed timestamp ${doc.timestamp}';
		final encoded = SuiteJson.stringify(result, "2026-07-17T12:00:00Z");
		final parsed:Dynamic = Json.parse(encoded);
		if (parsed.suite != "json_smoke" || parsed.target != "interp")
			throw "JsonSmoke: stringify/parse mismatch";
		if (parsed.results[0].name != "nop")
			throw "JsonSmoke: stringify missing results[0].name";
		if (Reflect.hasField(parsed.results[0], "totalSeconds"))
			throw "JsonSmoke: stringify should omit totalSeconds";

		Sys.println('JsonSmoke ok (wrote $outPath, haxe ${roundtrip.haxeVersion}, target ${roundtrip.target})');
	}
}
