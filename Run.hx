/**
	Haxelib / lix run entry (`"main": "Run"` in haxelib.json).

	When invoked via `haxelib run` / `lix run`, cwd starts at the library install
	path and the caller's directory is appended as the last argument. We switch
	cwd to the consumer project (same pattern as travix) before dispatching CLI.
**/
class Run {
	function new() {}

	static function main():Void {
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

		dispatch(args);
	}

	static function dispatch(args:Array<String>):Void {
		if (args.length == 0) {
			printUsage();
			Sys.exit(1);
			return;
		}

		final command = args[0];
		final rest = args.slice(1);

		switch (command) {
			case 'run':
				runStub(rest);
			case 'help' | '--help' | '-h':
				printUsage();
			case unknown:
				Sys.println('Unknown command: $unknown');
				printUsage();
				Sys.exit(1);
		}
	}

	/**
		Host multi-target runner — implemented in Phase 6.
		For target `js`, that phase must set `TRAVIX_CONFIG_DIR` to the absolute
		path of this package's `.travix/` config root (see `.travix/README.md`).
	**/
	static function runStub(args:Array<String>):Void {
		Sys.println('why-benchkit run: not implemented yet (Phase 6)');
		Sys.println('cwd: ${Sys.getCwd()}');
		if (args.length > 0)
			Sys.println('args: ${args.join(" ")}');
		Sys.exit(1);
	}

	static function printUsage():Void {
		Sys.println('Usage: haxelib run why-benchkit <command> [options]');
		Sys.println('   or: lix run why-benchkit <command> [options]');
		Sys.println('');
		Sys.println('Commands:');
		Sys.println('  run    Run benchmarks across targets (Phase 6)');
		Sys.println('  help   Show this help');
		Sys.println('');
		Sys.println('Examples:');
		Sys.println('  haxelib run why-benchkit run --targets interp,neko,node');
		Sys.println('  haxelib run why-benchkit run --targets js --json-dir out/');
	}
}
