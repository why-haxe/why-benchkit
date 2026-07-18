package why.benchkit.host;

import tink.cli.Rest;
import travix.Travix;
import haxe.ds.ReadOnlyArray;

@:forward
abstract Targets(ReadOnlyArray<Target>) from ReadOnlyArray<Target> to ReadOnlyArray<Target> {
	/** Known targets for help/docs (do not mutate; not a runtime default). */
	public static final ALL:Targets = ([Interp, Neko, Python, Node, Js, Lua, Cpp, Jvm] : ReadOnlyArray<Target>);

	@:from
	static function fromString(s:String):Targets {
		return (s.split(',').map(s -> (s : Target)) : ReadOnlyArray<Target>);
	}

	@:to
	function toStringArray():Array<String> {
		return [for (t in this) (t : String)];
	}
}

@:forward
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

	public function installAndRun(rest:Array<String>):Void {
		final t = @:privateAccess new Travix();
		final args:Rest<String> = rest;
		switch abstract {
			case Interp:
				t.interp(args);
			case Neko:
				t.neko(args);
			case Python:
				t.python(args);
			case Node:
				t.node(args);
			case Js:
				t.js(args);
			case Lua:
				t.lua(args);
			case Cpp:
				t.cpp(args);
			case Jvm:
				t.jvm(args);
		}
	}
}
