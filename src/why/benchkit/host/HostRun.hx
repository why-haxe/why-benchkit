package why.benchkit.host;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import travix.Travix;
import why.benchkit.BenchkitEnv;
import why.benchkit.Config.BenchkitConfig;
import why.benchkit.Config.ReporterSpec;
import why.benchkit.host.Targets;

/**
	Host multi-target runner: per-target travix `install` + `buildAndRun`.

	## Consumer suite entrypoint

	Uses `bench.hxml` in the consumer project cwd (`TRAVIX_HXML`) with a
	`-main` class that calls `Runner.run([...])`. The suite process owns
	reporting via `Config` / `WHY_BENCHKIT_CONFIG` (browser: `window.why.benchkit`,
	injected from the same env by packaged `.travix/js/hooks.js`).

	The consumer is responsible for installing project dependencies before
	invoking the host.

	`--targets` is required (e.g. `--targets interp` or `--targets node,js`).
	Optional `--json-dir` adds a per-target JSON reporter
	(`<dir>/<target>.json`) to the injected config alongside console.

	Uses travix's Haxe API directly (no `haxelib run travix` fallback).
**/
class HostRun {
	static final BENCH_HXML:String = 'bench.hxml';

	function new() {}

	/**
		Run the host orchestration. Exits the process on success (0) or after
		printing errors. Travix commands call `Sys.exit` on toolchain/build
		failure, which aborts remaining targets (same as `travix` CLI).

		For each target, injects `WHY_BENCHKIT_CONFIG` so the suite reports
		locally. Does not read suite result handoff files.
	**/
	public static function run(targets:Targets, libraryRoot:String, ?jsonDir:String):Void {
		ensureBenchHxml();

		final travixConfigDir = Path.normalize(Path.join([libraryRoot, '.travix']));
		final benchHxml = Path.join([Sys.getCwd(), BENCH_HXML]);

		if (!FileSystem.exists(benchHxml)) {
			Sys.println('why-benchkit: missing $BENCH_HXML in ${Sys.getCwd()}');
			Sys.println('Expected a suite hxml with `-main` calling Runner.run([...]).');
			Sys.exit(1);
			return;
		}

		if (targets.indexOf(Js) >= 0) {
			if (!FileSystem.exists(travixConfigDir) || !FileSystem.isDirectory(travixConfigDir)) {
				Sys.println('why-benchkit: packaged travix config missing: $travixConfigDir');
				Sys.println('Expected hooks at $travixConfigDir/js/hooks.js (set TRAVIX_CONFIG_DIR for js).');
				Sys.exit(1);
				return;
			}
			final hooks = Path.join([travixConfigDir, 'js', 'hooks.js']);
			if (!FileSystem.exists(hooks)) {
				Sys.println('why-benchkit: packaged js hooks missing: $hooks');
				Sys.exit(1);
				return;
			}
		}

		final jsonDirAbs:Null<String> = switch jsonDir {
			case null | '':
				null;
			case dir:
				ensureDir(dir);
				dir;
		};

		Sys.println('why-benchkit: running targets [${targets.join(", ")}]');
		if (jsonDirAbs != null)
			Sys.println('why-benchkit: json-dir $jsonDirAbs');

		for (target in targets) {
			Sys.putEnv(BenchkitEnv.CONFIG, configJson(target, jsonDirAbs));

			if (target == Js) {
				// Replaces cwd `.travix` for this run (not a merge). See `.travix/README.md`.
				// Hooks read WHY_BENCHKIT_CONFIG and inject window.why.benchkit.
				Sys.putEnv('TRAVIX_CONFIG_DIR', travixConfigDir);
			}

			Sys.println('why-benchkit: target $target');
			target.installAndRun([]);

			if (target == Js)
				Sys.putEnv('TRAVIX_CONFIG_DIR', '');
		}

		Sys.putEnv(BenchkitEnv.CONFIG, '');
		Sys.exit(0);
	}

	/**
		Build the suite-process config JSON for one target.
		Always includes console; adds json under `jsonDir/<target>.json` when set.
	**/
	static function configJson(target:Target, ?jsonDir:String):String {
		final reporters:Array<ReporterSpec> = [{name: 'console'}];
		if (jsonDir != null && jsonDir != '') {
			reporters.push({
				name: 'json',
				outputPath: Path.join([jsonDir, '$target.json']),
			});
		}
		final config:BenchkitConfig = {reporters: reporters};
		return Json.stringify(config);
	}

	/**
		Point travix at `bench.hxml`. Must update both the env and `Travix.TESTS`
		because the static may already have been initialized to `tests.hxml`.
	**/
	static function ensureBenchHxml():Void {
		Sys.putEnv('TRAVIX_HXML', BENCH_HXML);
		@:privateAccess Travix.TESTS = BENCH_HXML;
	}

	static function ensureDir(dir:String):Void {
		final normalized = Path.normalize(dir);
		if (FileSystem.exists(normalized)) {
			if (!FileSystem.isDirectory(normalized))
				throw 'why-benchkit: not a directory: $normalized';
			return;
		}
		final parent = Path.directory(normalized);
		if (parent != null && parent != '' && parent != normalized && !FileSystem.exists(parent))
			ensureDir(parent);
		FileSystem.createDirectory(normalized);
	}
}
