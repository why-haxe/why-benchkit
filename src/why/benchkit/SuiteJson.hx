package why.benchkit;

import haxe.Json;

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
