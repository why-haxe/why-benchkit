package why.benchkit;

/**
	Haxelib / lix run entry (`"main": "Run"` in haxelib.json).

	When invoked via `haxelib run` / `lix run`, cwd starts at the library install
	path and the caller's directory is appended as the last argument. We switch
	cwd to the consumer project (same pattern as travix) before dispatching CLI.

	For target `js`, the host sets `TRAVIX_CONFIG_DIR` to the absolute path of
	this package's `.travix/` config root (captured as `libraryRoot` before cwd
	handoff; see `.travix/README.md`).
**/
class Run {
	function new() {}

	static function main():Void {
		#if why_benchkit_check_run
		// Force-typecheck host modules (same graph as `run`) so check-run verifies Phase 6.
		final n = why.benchkit.host.HostTargets.DEFAULT.length;
		why.benchkit.host.HostArgs.parse([]);
		if (false)
			why.benchkit.host.HostRun.run([], Sys.getCwd());
		Sys.println('why-benchkit check-run ok ($n default targets)');
		Sys.exit(0);
		return;
		#end

		// Capture package root before haxelib/lix switches cwd to the consumer.
		final libraryRoot = Sys.getCwd();
		final args = Sys.args();

		// haxelib/lix set HAXELIB_RUN=1 and append the caller's directory.
		if (Sys.getEnv('HAXELIB_RUN') == '1' && args.length > 0) {
			final cwd = args.pop();
			try {
				Sys.setCwd(cwd);
			} catch (e:Dynamic) {
				Sys.println('why-benchkit: failed to switch to consumer directory: $cwd');
				Sys.println('($e)');
				Sys.exit(1);
				return;
			}
		}

		dispatch(args, libraryRoot);
	}

	static function dispatch(args:Array<String>, libraryRoot:String):Void {
		if (args.length == 0) {
			printUsage();
			Sys.exit(1);
			return;
		}

		final command = args[0];
		final rest = args.slice(1);

		switch (command) {
			case 'run':
				why.benchkit.host.HostRun.run(rest, libraryRoot);
			case 'help' | '--help' | '-h':
				printUsage();
			case unknown:
				Sys.println('Unknown command: $unknown');
				printUsage();
				Sys.exit(1);
		}
	}

	static function printUsage():Void {
		Sys.println('Usage: haxelib run why-benchkit <command> [options]');
		Sys.println('   or: lix run why-benchkit <command> [options]');
		Sys.println('');
		Sys.println('Commands:');
		Sys.println('  run    Run benchmarks across targets via travix');
		Sys.println('  help   Show this help');
		Sys.println('');
		Sys.println('Examples:');
		Sys.println('  haxelib run why-benchkit run --targets interp,neko,node');
		Sys.println('  haxelib run why-benchkit run --targets js --json-dir out/');
		Sys.println('');
		Sys.println('For run options: haxelib run why-benchkit run --help');
		Sys.println('Suite entrypoint: tests.hxml with -main calling suite.run() (travix convention).');
	}
}
