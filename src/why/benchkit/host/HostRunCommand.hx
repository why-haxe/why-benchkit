package why.benchkit.host;

/**
	`why-benchkit run` subcommand: run the consumer suite across targets via travix.
**/
@:alias(false)
class HostRunCommand {
	@:flag(false)
	final libraryRoot:String;

	/**
		Comma-separated targets (default: interp,neko,python,node,js,lua,cpp,jvm)
	**/
	@:alias(false)
	@:optional
	public var targets:Targets;

	/**
		Write `<dir>/<target>.json` per target (sets WHY_BENCHKIT_JSON)
	**/
	@:flag('json-dir')
	@:alias(false)
	@:optional
	public var jsonDir:String;

	public function new(libraryRoot:String) {
		this.libraryRoot = libraryRoot;
	}

	/**
		Run the consumer suite (tests.hxml) across one or more Haxe targets via travix.
		Install project dependencies yourself before invoking this command.
	**/
	@:defaultCommand
	public function run():Void {
		try {
			HostRun.run(new HostOptions(targets, emptyToNull(jsonDir)), libraryRoot);
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

	static function emptyToNull(s:String):Null<String> {
		return s == null || s.length == 0 ? null : s;
	}
}

enum abstract Target(String) to String {
	final Interp = "interp";
	final Neko = "neko";
	final Python = "python";
	final Node = "node";
	final Js = "js";
	final Lua = "lua";
	final Cpp = "cpp";
	final Jvm = "jvm";

	@:from
	static function fromString(s:String):Target {
		return switch (s) {
			case Interp: Interp;
			case Neko: Neko;
			case Python: Python;
			case Node: Node;
			case Js: Js;
			case Lua: Lua;
			case Cpp: Cpp;
			case Jvm: Jvm;
			case _: throw 'unknown target "$s"';
		}
	}
}

abstract Targets(Array<Target>) from Array<Target> to Array<Target> to Array<String> {
	@:from
	static function fromString(s:String):Targets {
		return s.split(',').map(s -> (s : Target));
	}
}
