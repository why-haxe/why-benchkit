package why.benchkit;

import haxe.Json;
import why.benchkit.reporter.ConsoleReporter;
import why.benchkit.reporter.JsonReporter;

/**
	Reporter configuration document (JSON).

	```json
	{
	  "target": "node",
	  "sampleCount": 5,
	  "reporters": [
		{ "name": "console" },
		{ "name": "json", "outputDir": "out/<commit-hash-or-_dirty>" }
	  ]
	}
	```

	Root `target` is the CLI/host target string used in the JSON filename
	(required when a `json` reporter is present).

	Optional top-level `sampleCount` is injected by the host (`--samples`) and
	applied by `Runner` to suite measures that omit an explicit count.
**/
typedef BenchkitConfig = {
	final ?target:String;
	final reporters:Array<ReporterSpec>;
	/** Host-injected timed-loop count for suite measures (optional; must be >= 1). */
	final ?sampleCount:Int;
}

/**
	One reporter entry in `BenchkitConfig.reporters`.
	`outputDir` is required when `name` is `"json"` (path is
	`<outputDir>/<haxeVersion>/<config.target>.json`).
**/
typedef ReporterSpec = {
	final name:String;
	final ?outputDir:String;
}

/**
	Load suite-process reporter config and build `Reporter` instances.

	- Native / node: `WHY_BENCHKIT_CONFIG` env (JSON string)
	- Browser `js`: `window.why.benchkit` (same shape; injected by `.travix/js/hooks.js`)
	- Missing / empty: default `[{ "name": "console" }]`
**/
class Config {
	function new() {}

	/**
		Resolve config from the environment (or default), then build reporters.
	**/
	public static function createReporters():Array<Reporter> {
		return reportersFrom(load());
	}

	/**
		Load config from env / browser inject, or the console-only default.
	**/
	public static function load():BenchkitConfig {
		final raw = readRaw();
		if (raw == null)
			return defaultConfig();
		return parse(raw);
	}

	/**
		Build reporter instances from an already-parsed config document.
	**/
	public static function reportersFrom(config:BenchkitConfig):Array<Reporter> {
		final out:Array<Reporter> = [];
		for (spec in config.reporters)
			out.push(createReporter(spec, config.target));
		return out;
	}

	static function defaultConfig():BenchkitConfig {
		return {
			reporters: [{name: 'console'}],
		};
	}

	static function parse(raw:Any):BenchkitConfig {
		if (raw == null)
			return defaultConfig();

		final reportersRaw:Dynamic = Reflect.field(raw, 'reporters');
		if (reportersRaw == null)
			return defaultConfig();
		if (!Std.isOfType(reportersRaw, Array))
			throw 'why.benchkit: config.reporters must be an array';

		final targetRaw:Dynamic = Reflect.field(raw, 'target');
		final target:Null<String> = targetRaw == null ? null : Std.string(targetRaw);

		final specs:Array<ReporterSpec> = [];
		var hasJson = false;
		for (item in (reportersRaw : Array<Dynamic>)) {
			if (item == null || !Reflect.isObject(item))
				throw 'why.benchkit: each config.reporters entry must be an object';
			final name:Dynamic = Reflect.field(item, 'name');
			if (name == null || !Std.isOfType(name, String) || (name : String).length == 0)
				throw 'why.benchkit: reporter config requires a non-empty name';
			final nameStr = (name : String);
			if (nameStr == 'json' && Reflect.hasField(item, 'outputPath') && Reflect.field(item, 'outputPath') != null)
				throw 'why.benchkit: json reporter uses outputDir (not outputPath)';
			final outputDir:Dynamic = Reflect.field(item, 'outputDir');
			final spec:ReporterSpec = {
				name: nameStr,
				outputDir: outputDir == null ? null : Std.string(outputDir),
			};
			if (nameStr == 'json')
				hasJson = true;
			specs.push(spec);
		}
		if (hasJson && (target == null || target.length == 0))
			throw 'why.benchkit: config.target is required when a json reporter is present';

		final sampleCount = parseSampleCount(Reflect.field(raw, 'sampleCount'));
		return {
			target: target,
			reporters: specs,
			sampleCount: sampleCount,
		};
	}

	/**
		Parse optional top-level `sampleCount` from JSON (numbers may be Float).
		Returns `null` when omitted; rejects values &lt; 1.
	**/
	static function parseSampleCount(raw:Dynamic):Null<Int> {
		if (raw == null)
			return null;
		final n = if (Std.isOfType(raw, Int)) {
			(raw : Int);
		} else if (Std.isOfType(raw, Float)) {
			final f = (raw : Float);
			final asInt = Std.int(f);
			// JSON numbers are often Float; reject non-integers (e.g. 3.5).
			if (f != asInt)
				throw 'why.benchkit: config.sampleCount must be an integer >= 1';
			asInt;
		} else
			throw 'why.benchkit: config.sampleCount must be an integer >= 1';
		if (n < 1)
			throw 'why.benchkit: config.sampleCount must be >= 1';
		return n;
	}

	static function createReporter(spec:ReporterSpec, ?target:String):Reporter {
		return switch spec.name {
			case 'console':
				new ConsoleReporter();
			case 'json':
				final dir = spec.outputDir;
				if (dir == null || dir.length == 0)
					throw 'why.benchkit: json reporter requires outputDir';
				if (target == null || target.length == 0)
					throw 'why.benchkit: config.target is required when a json reporter is present';
				new JsonReporter(dir, target);
			case other:
				throw 'why.benchkit: unknown reporter "${other}"';
		}
	}

	/**
		Raw config object from env JSON or `window.why.benchkit`, or `null` if omitted.
	**/
	static function readRaw():Null<Any> {
		#if (js && !nodejs)
		return readBrowser();
		#else
		return readEnv();
		#end
	}

	#if !(js && !nodejs)
	static function readEnv():Null<Any> {
		final fromEnv = Sys.getEnv(BenchkitEnv.CONFIG);
		if (fromEnv == null || fromEnv.length == 0)
			return null;
		try {
			return Json.parse(fromEnv);
		} catch (e:Dynamic) {
			throw 'why.benchkit: invalid ${BenchkitEnv.CONFIG} JSON: ${Std.string(e)}';
		}
	}
	#end

	#if (js && !nodejs)
	static function readBrowser():Null<Any> {
		// Injected by packaged travix hooks: window.why.benchkit
		final why:Dynamic = untyped js.Browser.window.why;
		if (why == null)
			return null;
		final config:Dynamic = why.benchkit;
		if (config == null)
			return null;
		return config;
	}
	#end
}
