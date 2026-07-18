package why.benchkit;

import haxe.Json;
import why.benchkit.reporter.ConsoleReporter;
import why.benchkit.reporter.JsonReporter;

/**
	Reporter configuration document (JSON).

	```json
	{
	  "reporters": [
		{ "name": "console" },
		{ "name": "json", "outputPath": "out/js.json" }
	  ]
	}
	```
**/
typedef BenchkitConfig = {
	final reporters:Array<ReporterSpec>;
}

/**
	One reporter entry in `BenchkitConfig.reporters`.
	`outputPath` is required when `name` is `"json"`.
**/
typedef ReporterSpec = {
	final name:String;
	final ?outputPath:String;
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
			out.push(createReporter(spec));
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

		final specs:Array<ReporterSpec> = [];
		for (item in (reportersRaw : Array<Dynamic>)) {
			if (item == null || !Reflect.isObject(item))
				throw 'why.benchkit: each config.reporters entry must be an object';
			final name:Dynamic = Reflect.field(item, 'name');
			if (name == null || !Std.isOfType(name, String) || (name : String).length == 0)
				throw 'why.benchkit: reporter config requires a non-empty name';
			final outputPath:Dynamic = Reflect.field(item, 'outputPath');
			final spec:ReporterSpec = {
				name: (name : String),
				outputPath: outputPath == null ? null : Std.string(outputPath),
			};
			specs.push(spec);
		}
		return {reporters: specs};
	}

	static function createReporter(spec:ReporterSpec):Reporter {
		return switch spec.name {
			case 'console':
				new ConsoleReporter();
			case 'json':
				final path = spec.outputPath;
				if (path == null || path.length == 0)
					throw 'why.benchkit: json reporter requires outputPath';
				new JsonReporter(path);
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
