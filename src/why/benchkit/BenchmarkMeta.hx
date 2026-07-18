package why.benchkit;

import haxe.macro.Compiler;

/**
	Metadata helpers for `BenchmarkResult` (folded from BuildInfo / RuntimeTarget / UtcIso).
**/
class BenchmarkMeta {
	function new() {}

	/** Haxe version string (e.g. `"4.3.7"`), from define `haxe`. */
	public static function haxeVersion():String {
		return Compiler.getDefine('haxe');
	}

	/** Target id from define `target.name` (e.g. `"interp"`, `"js"`). */
	public static function target():String {
		return Compiler.getDefine('target.name');
	}
}
