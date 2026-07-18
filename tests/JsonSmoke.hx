import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import why.benchkit.BenchkitEnv;
import why.benchkit.BenchmarkMeta;
import why.benchkit.BenchmarkResult;
import why.benchkit.Config;
import why.benchkit.Reporter;
import why.benchkit.reporter.ConsoleReporter;
import why.benchkit.reporter.JsonReporter;
import why.unit.time.Millisecond;

/**
	Config + JsonReporter smoke on interp (new `BenchmarkResult` shape).
	Usage: haxe json.hxml
**/
class JsonSmoke {
	static function main():Void {
		assertConfigParse();
		assertJsonReporterWrite();
		Sys.println("JsonSmoke ok");
	}

	static function assertConfigParse():Void {
		final consoleOnly = Config.reportersFrom({
			reporters: [{name: "console"}],
		});
		if (consoleOnly.length != 1)
			throw 'JsonSmoke: expected 1 console reporter, got ${consoleOnly.length}';

		if (!FileSystem.exists("dump"))
			FileSystem.createDirectory("dump");
		final outPath = "dump/json_smoke_config.json";
		if (FileSystem.exists(outPath))
			FileSystem.deleteFile(outPath);

		Sys.putEnv(BenchkitEnv.CONFIG, Json.stringify({
			reporters: [{name: "console"}, {name: "json", outputPath: outPath},],
		}));
		final fromEnv = Config.createReporters();
		if (fromEnv.length != 2)
			throw 'JsonSmoke: expected 2 reporters from env, got ${fromEnv.length}';
		if (!Std.isOfType(fromEnv[0], ConsoleReporter))
			throw "JsonSmoke: expected first env reporter to be ConsoleReporter";
		if (!Std.isOfType(fromEnv[1], JsonReporter))
			throw "JsonSmoke: expected second env reporter to be JsonReporter";

		final envDoc:BenchmarkResult = {
			haxeVersion: "test",
			target: "eval",
			timestamp: 0,
			results: [],
			commitHash: "deadbeef",
		};
		for (r in fromEnv)
			r.report(envDoc);
		if (!FileSystem.exists(outPath))
			throw 'JsonSmoke: Config.createReporters JsonReporter did not write $outPath';

		var threw = false;
		try {
			Config.reportersFrom({
				reporters: [{name: "json"}],
			});
		} catch (e:Dynamic) {
			threw = true;
		}
		if (!threw)
			throw "JsonSmoke: expected json reporter without outputPath to throw";

		threw = false;
		try {
			Config.reportersFrom({
				reporters: [{name: "nope"}],
			});
		} catch (e:Dynamic) {
			threw = true;
		}
		if (!threw)
			throw "JsonSmoke: expected unknown reporter to throw";

		// Clear so later steps do not inherit this config.
		Sys.putEnv(BenchkitEnv.CONFIG, "");
	}

	static function assertJsonReporterWrite():Void {
		if (!FileSystem.exists("dump"))
			FileSystem.createDirectory("dump");
		final outPath = "dump/json_smoke.json";
		if (FileSystem.exists(outPath))
			FileSystem.deleteFile(outPath);

		final doc:BenchmarkResult = {
			haxeVersion: BenchmarkMeta.haxeVersion(),
			target: BenchmarkMeta.target(),
			timestamp: 0,
			results: [
				{
					name: "json_smoke",
					results: [
						{
							name: "nop",
							duration: new Millisecond(1.5),
							iterations: 1,
							warmup: 0,
						},
					],
				},
			],
			commitHash: BenchmarkMeta.gitHash(),
		};

		final reporter:Reporter = new JsonReporter(outPath);
		reporter.report(doc);

		if (!FileSystem.exists(outPath))
			throw 'JsonSmoke: JsonReporter did not write $outPath';

		final roundtrip:Dynamic = Json.parse(File.getContent(outPath));
		if (roundtrip.haxeVersion == null || roundtrip.haxeVersion == "" || roundtrip.haxeVersion == "unknown")
			throw 'JsonSmoke: bad haxeVersion ${roundtrip.haxeVersion}';
		// `--interp` sets define target.name to "eval".
		if (roundtrip.target != "eval")
			throw 'JsonSmoke: expected target eval, got ${roundtrip.target}';
		if (roundtrip.timestamp != 0)
			throw 'JsonSmoke: bad timestamp ${roundtrip.timestamp}';
		if (roundtrip.commitHash == null || roundtrip.commitHash == "")
			throw 'JsonSmoke: bad commitHash ${roundtrip.commitHash}';
		if (roundtrip.results == null || roundtrip.results.length != 1)
			throw 'JsonSmoke: results length ${roundtrip.results == null ? "null" : Std.string(roundtrip.results.length)}';
		final suite0 = roundtrip.results[0];
		if (suite0.name != "json_smoke")
			throw 'JsonSmoke: suite name ${suite0.name}';
		if (suite0.results == null || suite0.results.length != 1)
			throw 'JsonSmoke: measure count ${suite0.results == null ? "null" : Std.string(suite0.results.length)}';
		final m0 = suite0.results[0];
		if (m0.name != "nop")
			throw 'JsonSmoke: measure name ${m0.name}';
		if (!Math.isFinite(m0.duration) || m0.duration != 1.5)
			throw 'JsonSmoke: bad duration ${m0.duration}';
		if (m0.iterations != 1 || m0.warmup != 0)
			throw 'JsonSmoke: bad iterations/warmup ${m0.iterations}/${m0.warmup}';
		// New shape: no flat suite / opsPerSec / totalMs fields.
		if (Reflect.hasField(roundtrip, "suite"))
			throw "JsonSmoke: JSON should omit flat suite field";
		if (Reflect.hasField(m0, "totalMs") || Reflect.hasField(m0, "opsPerSec"))
			throw "JsonSmoke: measure should omit totalMs / opsPerSec";

		Sys.println('JsonSmoke wrote $outPath (haxe ${roundtrip.haxeVersion}, target ${roundtrip.target})');
	}
}
