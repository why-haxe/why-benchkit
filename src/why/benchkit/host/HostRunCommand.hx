package why.benchkit.host;

/**
	`why-benchkit run` subcommand: run the consumer suite across targets via travix.
**/
@:alias(false)
class HostRunCommand {
	@:flag(false)
	final libraryRoot:String;

	/**
		Comma-separated targets (required). Known: interp,neko,python,node,js,lua,cpp,jvm
	**/
	@:alias(false)
	@:optional
	public var targets:Targets;

	/**
		Directory for nested JSON output (`<dir>/<sha|_dirty>/<haxeVer>/<target>.json`)
	**/
	@:flag('json-dir')
	@:alias(false)
	@:optional
	public var jsonDir:String;

	/**
		Independent timed loops per measure after warmup (default 5). Must be >= 1.
	**/
	@:alias(false)
	public var samples:Int = 5;

	public function new(libraryRoot:String) {
		this.libraryRoot = libraryRoot;
	}

	/**
		Run the consumer suite (`bench.hxml`) across one or more Haxe targets via travix.
		Install project dependencies yourself before invoking this command.
		Maps `HostRun` status to process exit (travix may still `Sys.exit` on toolchain failure).
	**/
	@:defaultCommand
	public function run():Void {
		try {
			if (targets == null || targets.length == 0) {
				Sys.println('why-benchkit: --targets is required');
				Sys.println('Known targets: ${Targets.ALL.join(",")}');
				Sys.exit(1);
				return;
			}
			if (samples < 1) {
				Sys.println('why-benchkit: --samples must be >= 1');
				Sys.exit(1);
				return;
			}
			final jsonOutputDir = switch jsonDir {
				case null | '':
					null;
				case dir:
					final trimmed = StringTools.trim(dir);
					if (trimmed.length == 0)
						null;
					else
						haxe.io.Path.normalize(absolutePath(trimmed));
			};
			final status = HostRun.run(targets, libraryRoot, jsonOutputDir, samples);
			Sys.exit(status);
		} catch (e:Dynamic) {
			Sys.println(Std.string(e));
			Sys.exit(1);
		}
	}

	/**
		Show this help
	**/
	@:command
	@:skipFlags
	public function help():Void {
		Sys.println(tink.Cli.getDoc(this, new tink.cli.doc.DefaultFormatter('why-benchkit run')));
	}

	static function absolutePath(path:String):String {
		if (haxe.io.Path.isAbsolute(path))
			return path;
		return haxe.io.Path.join([Sys.getCwd(), path]);
	}
}
