package why.benchkit.host;

import haxe.io.Path;
import sys.FileSystem;
import travix.Travix;
import why.benchkit.host.Targets;

/**
	Host multi-target runner: per-target travix `install` + `buildAndRun`.

	## Consumer suite entrypoint

	Uses `bench.hxml` in the consumer project cwd (`TRAVIX_HXML`) with a
	`-main` class that calls `Runner.run([...])`. The suite process owns
	reporting via `Config` / `WHY_BENCHKIT_CONFIG` (browser: `window.why.benchkit`).

	The consumer is responsible for installing project dependencies before
	invoking the host.

	`--targets` is required (e.g. `--targets interp` or `--targets node,js`).
	Host config inject for reporters / `--json-dir` is Chunk 07.

	Uses travix's Haxe API directly (no `haxelib run travix` fallback).
**/
class HostRun {
	static final BENCH_HXML:String = 'bench.hxml';

	function new() {}

	/**
		Run the host orchestration. Exits the process on success (0) or after
		printing errors. Travix commands call `Sys.exit` on toolchain/build
		failure, which aborts remaining targets (same as `travix` CLI).

		`jsonDir` is accepted for CLI compatibility; config inject lands in Chunk 07.
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

		Sys.println('why-benchkit: running targets [${targets.join(", ")}]');

		for (target in targets) {
			if (target == Js) {
				// Replaces cwd `.travix` for this run (not a merge). See `.travix/README.md`.
				Sys.putEnv('TRAVIX_CONFIG_DIR', travixConfigDir);
			}

			Sys.println('why-benchkit: target $target');
			target.installAndRun([]);

			if (target == Js)
				Sys.putEnv('TRAVIX_CONFIG_DIR', '');
		}

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
}
