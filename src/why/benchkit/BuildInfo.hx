package why.benchkit;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
	Compile-time build metadata for suite JSON.
**/
class BuildInfo {
	function new() {}

	/** Haxe version string (e.g. `"4.3.7"`), baked in at compile time. */
	public static macro function haxeVersion():Expr {
		final v = Context.definedValue("haxe");
		return macro $v{v != null ? v : "unknown"};
	}
}
