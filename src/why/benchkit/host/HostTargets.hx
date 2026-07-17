package why.benchkit.host;

import travix.commands.CppCommand;
import travix.commands.InterpCommand;
import travix.commands.JsCommand;
import travix.commands.JvmCommand;
import travix.commands.LuaCommand;
import travix.commands.NekoCommand;
import travix.commands.NodeCommand;
import travix.commands.PythonCommand;

/**
	Default host target list (aligned with travix) and per-target command dispatch.

	Uses travix's Haxe API (`install` then `buildAndRun`) rather than shelling out to
	`haxelib run travix`. No CLI fallback is required for this surface.
**/
class HostTargets {
	function new() {}

	/** Default `--targets` when the flag is omitted (do not mutate). */
	public static final DEFAULT:Array<String> = [
		'interp', 'neko', 'python', 'node', 'js', 'lua', 'cpp', 'jvm'
	];

	public static function isKnown(name:String):Bool {
		return switch (name) {
			case 'interp' | 'neko' | 'python' | 'node' | 'js' | 'lua' | 'cpp' | 'jvm':
				true;
			case _:
				false;
		};
	}

	/**
		Install toolchain/deps for `name`, then compile and run the suite via travix.
		`rest` is extra Haxe compiler args forwarded to `buildAndRun` (usually empty).
	**/
	public static function installAndRun(name:String, rest:Array<String>):Void {
		switch (name) {
			case 'interp':
				final c = new InterpCommand();
				c.install();
				c.buildAndRun(rest);
			case 'neko':
				final c = new NekoCommand();
				c.install();
				c.buildAndRun(rest);
			case 'python':
				final c = new PythonCommand();
				c.install();
				c.buildAndRun(rest);
			case 'node':
				final c = new NodeCommand();
				c.install();
				c.buildAndRun(rest);
			case 'js':
				final c = new JsCommand();
				c.install();
				c.buildAndRun(rest);
			case 'lua':
				final c = new LuaCommand();
				c.install();
				c.buildAndRun(rest);
			case 'cpp':
				final c = new CppCommand();
				c.install();
				c.buildAndRun(rest);
			case 'jvm':
				final c = new JvmCommand();
				c.install();
				c.buildAndRun(rest);
			case unknown:
				throw 'why-benchkit: internal error — unhandled target $unknown';
		}
	}
}
