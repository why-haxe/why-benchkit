package why.benchkit.host;

import haxe.io.Path;
import sys.FileSystem;
import travix.Travix;
import travix.commands.InstallCommand;
import why.benchkit.BenchkitEnv;

/**
	Host multi-target runner: install shared deps, then per-target travix
	`install` + `buildAndRun`.

	## Consumer suite entrypoint

	Uses travix's convention: a `tests.hxml` in the consumer project cwd with a
	`-main` class that builds and calls `suite.run()` (which prints the summary
	and honors `--json` / `WHY_BENCHKIT_JSON`).

	Also requires a root `haxelib.json` so `travix.commands.InstallCommand` can
	register the project (`haxelib dev`) and install declared dependencies.

	Single-target: pass one name in `--targets` (e.g. `--targets interp`).
	You can also compile/run the suite yourself and pass `--json <path>` where
	the target supports filesystem write (sys / node); browser `js` needs the
	packaged hooks (`TRAVIX_CONFIG_DIR`) and `window.benchkitWriteFile`.

	Uses travix's Haxe API directly (no `haxelib run travix` fallback).
**/
class HostRun {
	function new() {}

	/**
		Run the host orchestration. Exits the process on success (0) or after
		printing usage/errors. Travix commands call `Sys.exit` on toolchain/build
		failure, which aborts remaining targets (same as `travix` CLI).
	**/
	public static function run(args:Array<String>, libraryRoot:String):Void {
		final travixConfigDir = Path.normalize(Path.join([libraryRoot, '.travix']));

		var parsed:Null<HostOptions> = null;
		try {
			parsed = HostArgs.parse(args);
		} catch (e:Dynamic) {
			Sys.println(Std.string(e));
			printRunUsage();
			Sys.exit(1);
			return;
		}

		if (parsed == null) {
			printRunUsage();
			Sys.exit(0);
			return;
		}

		final opts:HostOptions = parsed;

		if (!FileSystem.exists(Travix.TESTS)) {
			Sys.println('why-benchkit: missing ${Travix.TESTS} in ${Sys.getCwd()}');
			Sys.println('Expected a travix-style suite hxml with `-main` calling suite.run().');
			Sys.exit(1);
			return;
		}

		if (!FileSystem.exists(Travix.HAXELIB_CONFIG)) {
			Sys.println('why-benchkit: missing ${Travix.HAXELIB_CONFIG} in ${Sys.getCwd()}');
			Sys.println('InstallCommand needs it to register the project and install dependencies.');
			Sys.exit(1);
			return;
		}

		if (opts.targets.indexOf('js') >= 0) {
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

		final jsonDirAbs:Null<String> = switch (opts.jsonDir) {
			case null: null;
			case dir:
				final abs = absolutePath(dir);
				ensureDir(abs);
				abs;
		};

		Sys.println('why-benchkit: running targets [${opts.targets.join(", ")}]');
		if (jsonDirAbs != null)
			Sys.println('why-benchkit: json-dir $jsonDirAbs');

		// Shared haxelib/lix deps from haxelib.json + tests.hxml (travix InstallCommand).
		// new InstallCommand().dependencies();

		final nameWidth = maxNameWidth(opts.targets);
		for (target in opts.targets) {
			final jsonPath:Null<String> = jsonDirAbs == null ? null : Path.join([jsonDirAbs, '$target.json']);
			if (jsonPath != null)
				Sys.putEnv(BenchkitEnv.JSON_PATH, jsonPath);
			else
				Sys.putEnv(BenchkitEnv.JSON_PATH, '');

			if (target == 'js') {
				// Replaces cwd `.travix` for this run (not a merge). See `.travix/README.md`.
				Sys.putEnv('TRAVIX_CONFIG_DIR', travixConfigDir);
			}

			HostTargets.installAndRun(target, []);
			printTargetLine(target, nameWidth, jsonPath);

			if (target == 'js')
				Sys.putEnv('TRAVIX_CONFIG_DIR', '');
		}

		Sys.exit(0);
	}

	static function printTargetLine(target:String, nameWidth:Int, jsonPath:Null<String>):Void {
		final pad = StringTools.rpad(target, ' ', nameWidth);
		if (jsonPath != null)
			Sys.println('  $pad  ok  ($jsonPath)');
		else
			Sys.println('  $pad  ok');
	}

	static function maxNameWidth(targets:Array<String>):Int {
		var w = 0;
		for (t in targets)
			if (t.length > w)
				w = t.length;
		return w;
	}

	static function absolutePath(path:String):String {
		if (Path.isAbsolute(path))
			return Path.normalize(path);
		return Path.normalize(Path.join([Sys.getCwd(), path]));
	}

	static function ensureDir(dir:String):Void {
		final normalized = Path.normalize(dir);
		if (FileSystem.exists(normalized)) {
			if (!FileSystem.isDirectory(normalized))
				throw 'why-benchkit: --json-dir is not a directory: $normalized';
			return;
		}
		final parent = Path.directory(normalized);
		if (parent != null && parent != '' && parent != normalized && !FileSystem.exists(parent))
			ensureDir(parent);
		FileSystem.createDirectory(normalized);
	}

	public static function printRunUsage():Void {
		Sys.println('Usage: haxelib run why-benchkit run [options]');
		Sys.println('   or: lix run why-benchkit run [options]');
		Sys.println('');
		Sys.println('Run the consumer suite (tests.hxml) across one or more Haxe targets via travix.');
		Sys.println('');
		Sys.println('Options:');
		Sys.println('  --targets a,b,c   Targets (default: ${HostTargets.DEFAULT.join(",")})');
		Sys.println('  --json-dir <dir>  Write <dir>/<target>.json per target (sets WHY_BENCHKIT_JSON)');
		Sys.println('  -h, --help        Show this help');
		Sys.println('');
		Sys.println('Suite entrypoint: tests.hxml with -main calling suite.run() (travix convention).');
		Sys.println('Requires haxelib.json so InstallCommand can install project dependencies.');
		Sys.println('');
		Sys.println('Single-target example:');
		Sys.println('  haxelib run why-benchkit run --targets interp --json-dir out/');
		Sys.println('');
		Sys.println('Or run a compiled suite directly with --json <path> where filesystem write works.');
		Sys.println('For browser js, the host sets TRAVIX_CONFIG_DIR to this package\'s .travix/.');
	}
}
