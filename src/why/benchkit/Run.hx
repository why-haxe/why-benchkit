package why.benchkit;

import why.benchkit.host.HostManifestCommand;
import why.benchkit.host.HostRunCommand;

/**
	Haxelib / lix run entry (`"main": "why.benchkit.Run"` in haxelib.json).
**/
@:alias(false)
class Run {
	@:flag(false)
	final libraryRoot:String;

	/**
		Run benchmarks across targets via travix
	**/
	@:command
	public final run:HostRunCommand;

	/**
		Rebuild the root clean-commit JSON catalog under `--json-dir`
	**/
	@:command
	public final manifest:HostManifestCommand;

	public function new(libraryRoot:String) {
		this.libraryRoot = libraryRoot;
		this.run = new HostRunCommand(libraryRoot);
		this.manifest = new HostManifestCommand();
	}

	static function main():Void {
		// Capture package root before haxelib/lix switches cwd to the consumer.
		// When HAXELIB_RUN=1, the caller's directory is appended as the last arg
		// (same pattern as travix). libraryRoot is kept for packaged `.travix/`.
		final libraryRoot = Sys.getCwd();
		final args = Sys.args();

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

		tink.Cli.process(args, new Run(libraryRoot)).handle(tink.Cli.exit);
	}

	/**
		Show help
	**/
	@:defaultCommand
	public function help():Void {
		Sys.println(tink.Cli.getDoc(this, new tink.cli.doc.DefaultFormatter('why-benchkit')));
	}
}
