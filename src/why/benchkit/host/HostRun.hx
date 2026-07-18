package why.benchkit.host;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import travix.Travix;
import why.benchkit.BenchkitEnv;
import why.benchkit.BenchmarkResult;
import why.benchkit.Reporter;
import why.benchkit.host.Targets;
import why.benchkit.reporter.JsonReporter;

/**
	Host multi-target runner: per-target travix `install` + `buildAndRun`.

	## Consumer suite entrypoint

	Uses `bench.hxml` in the consumer project cwd (`TRAVIX_HXML`) with a
	`-main` class that builds and calls `suite.run()`. Under the host, the suite
	hands off a `BenchmarkResult` via `WHY_BENCHKIT_RESULT` (browser: object
	through `window.benchkitComplete`); the host runs reporters.

	The consumer is responsible for installing project dependencies before
	invoking the host.

	`--targets` is required (e.g. `--targets interp` or `--targets node,js`).
	Standalone suite reporting uses `Config` / `WHY_BENCHKIT_CONFIG` (Chunk 03);
	host still injects `WHY_BENCHKIT_RESULT` until Chunks 06/07.

	Uses travix's Haxe API directly (no `haxelib run travix` fallback).
**/
class HostRun {
	static final BENCH_HXML:String = 'bench.hxml';

	function new() {}

	/**
		Run the host orchestration. Exits the process on success (0) or after
		printing errors. Travix commands call `Sys.exit` on toolchain/build
		failure, which aborts remaining targets (same as `travix` CLI).
	**/
	public static function run(
		targets:Targets,
		reporters:Array<Reporter>,
		libraryRoot:String,
		?jsonDir:String
	):Void {
		ensureBenchHxml();

		final travixConfigDir = Path.normalize(Path.join([libraryRoot, '.travix']));
		final benchHxml = Path.join([Sys.getCwd(), BENCH_HXML]);

		if (!FileSystem.exists(benchHxml)) {
			Sys.println('why-benchkit: missing $BENCH_HXML in ${Sys.getCwd()}');
			Sys.println('Expected a suite hxml with `-main` calling suite.run().');
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

		final resultDir = Path.join([Sys.getCwd(), 'bin', 'benchkit-results']);
		ensureDir(resultDir);

		Sys.println('why-benchkit: running targets [${targets.join(", ")}]');

		for (target in targets) {
			final resultPath = Path.join([resultDir, '$target.json']);
			Sys.putEnv(BenchkitEnv.RESULT_PATH, resultPath);
			// Clear standalone JSON env so suite stays in host handoff mode only.
			Sys.putEnv(BenchkitEnv.JSON_PATH, '');

			if (target == Js) {
				// Replaces cwd `.travix` for this run (not a merge). See `.travix/README.md`.
				Sys.putEnv('TRAVIX_CONFIG_DIR', travixConfigDir);
			}

			Sys.println('why-benchkit: target $target');
			target.installAndRun([]);

			final doc = readResult(resultPath);
			for (r in reporters)
				r.report(doc);
			if (jsonDir != null && jsonDir != '')
				new JsonReporter(Path.join([jsonDir, '${doc.target}.json'])).report(doc);

			if (target == Js)
				Sys.putEnv('TRAVIX_CONFIG_DIR', '');
		}

		Sys.putEnv(BenchkitEnv.RESULT_PATH, '');
		Sys.exit(0);
	}

	/**
		Point travix at `bench.hxml`. Must update both the env and `Travix.TESTS`
		because the static may already have been initialized to `tests.hxml`.
	**/
	static function ensureBenchHxml():Void {
		Sys.putEnv('TRAVIX_HXML', BENCH_HXML);
		@:privateAccess Travix.TESTS = BENCH_HXML;
	}

	static function readResult(path:String):BenchmarkResult {
		if (!FileSystem.exists(path))
			throw 'why-benchkit: missing suite result handoff at $path';
		final raw = File.getContent(path);
		return (Json.parse(raw) : BenchmarkResult);
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
