package why.benchkit;

import haxe.Json;

/**
	One entry in the suite JSON `results` array (Design reference shape).
**/
typedef SuiteJsonCase = {
	final name:String;
	final iterations:Int;
	final warmup:Int;
	final totalMs:Float;
	final opsPerSec:Float;
}

/**
	Top-level suite JSON document written for `--json <path>`.
**/
typedef SuiteJsonDocument = {
	final suite:String;
	final target:String;
	final haxeVersion:String;
	final timestamp:String;
	final results:Array<SuiteJsonCase>;
}

/**
	Serialize `SuiteResult` to the roadmap JSON shape.
**/
class SuiteJson {
	function new() {}

	public static function fromSuiteResult(result:SuiteResult, ?timestamp:String):SuiteJsonDocument {
		final cases:Array<SuiteJsonCase> = [];
		for (r in result.results) {
			cases.push({
				name: r.name,
				iterations: r.iterations,
				warmup: r.warmup,
				totalMs: r.totalMs,
				opsPerSec: r.opsPerSec,
			});
		}
		return {
			suite: result.name,
			target: RuntimeTarget.name(),
			haxeVersion: BuildInfo.haxeVersion(),
			timestamp: timestamp ?? UtcIso.now(),
			results: cases,
		};
	}

	public static function stringify(result:SuiteResult, ?timestamp:String):String {
		return Json.stringify(fromSuiteResult(result, timestamp));
	}
}
