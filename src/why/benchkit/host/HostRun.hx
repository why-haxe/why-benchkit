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
	Optional `--json-dir` writes nested JSON under `<json-dir>/<sha>/` or
	`<json-dir>/_dirty/`, updates that folder's `manifest.json`, and rebuilds
	the root clean-commit catalog.
	Optional `--samples` (default 5) is injected as top-level `sampleCount` on
	`BenchkitConfig` so the suite applies it to measures that omit an explicit count.

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
	public static function run(targets:Targets, libraryRoot:String, ?jsonDir:String, sampleCount:Int = 5):Void {
		if (sampleCount < 1)
			throw 'why-benchkit: sampleCount must be >= 1';
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

		final jsonOutput = switch jsonDirAbs {
			case null:
				null;
			case dir:
				final resolved = HostGit.resolveOutput(dir);
				ensureDir(resolved.path);
				resolved;
		};

		Sys.println('why-benchkit: running targets [${targets.join(", ")}]');
		Sys.println('why-benchkit: samples $sampleCount');
		if (jsonDirAbs != null && jsonOutput != null) {
			Sys.println('why-benchkit: json-dir $jsonDirAbs');
			Sys.println('why-benchkit: json output ${jsonOutput.path}' + (jsonOutput.dirty ? ' (dirty)' : ''));
		}

		for (target in targets) {
			Sys.putEnv(BenchkitEnv.CONFIG, configJson(target, sampleCount, jsonOutput != null ? jsonOutput.path : null));

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

		if (jsonDirAbs != null && jsonOutput != null) {
			final timestamp = jsonOutput.dirty ? Date.now().getTime() : jsonOutput.timestamp;
			JsonManifest.writeFolderManifest(jsonOutput.path, timestamp);
			JsonManifest.rebuild(jsonDirAbs);
		}

		Sys.exit(0);
	}

	/**
		Build the suite-process config JSON for one target.
		Always includes console; adds json under
		`<outputDir>/<haxeVersion>/<target>.json` when `outputDir` is set
		(root `target` + reporter `outputDir`).
		Always sets top-level `sampleCount` from the host `--samples` value.
	**/
	static function configJson(target:Target, sampleCount:Int, ?outputDir:String):String {
		final reporters:Array<ReporterSpec> = [{name: 'console'}];
		if (outputDir != null && outputDir != '') {
			reporters.push({
				name: 'json',
				outputDir: outputDir,
			});
		}
		final config:BenchkitConfig = {
			target: target,
			reporters: reporters,
			sampleCount: sampleCount,
		};
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
