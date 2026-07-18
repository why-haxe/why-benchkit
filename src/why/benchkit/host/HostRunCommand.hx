package why.benchkit.host;

import why.benchkit.Reporter;
import why.benchkit.reporter.ConsoleReporter;

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
		Write `<dir>/<target>.json` per target after host receives suite handoff
	**/
	@:flag('json-dir')
	@:alias(false)
	@:optional
	public var jsonDir:String;

	public function new(libraryRoot:String) {
		this.libraryRoot = libraryRoot;
	}

	/**
		Run the consumer suite (`bench.hxml`) across one or more Haxe targets via travix.
		Install project dependencies yourself before invoking this command.
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
			final reporters:Array<Reporter> = [new ConsoleReporter()];
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
			HostRun.run(targets, reporters, libraryRoot, jsonOutputDir);
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
