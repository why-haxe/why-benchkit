package why.benchkit;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
	Metadata helpers for `BenchmarkResult` (folded from BuildInfo / RuntimeTarget / UtcIso).
**/
class BenchmarkMeta {
	function new() {}

	/** Haxe version string (e.g. `"4.3.7"`), from define `haxe`. */
	public static macro function haxeVersion():Expr {
		final v = Context.definedValue("haxe");
		return macro $v{v != null ? v : "unknown"};
	}

	/** Target id from define `target.name` (e.g. `"interp"`, `"js"`). */
	public static macro function target():Expr {
		final v = Context.definedValue("target.name");
		return macro $v{v != null ? v : "unknown"};
	}

	/** UTC ISO-8601 timestamp (`YYYY-MM-DDTHH:MM:SSZ`) for now. */
	public static function timestampNow():String {
		return formatTimestamp(Date.now());
	}

	/** UTC ISO-8601 timestamp (`YYYY-MM-DDTHH:MM:SSZ`) for `date`. */
	public static function formatTimestamp(date:Date):String {
		// Shift so local getters yield UTC components.
		final utc = Date.fromTime(date.getTime() + date.getTimezoneOffset() * 60 * 1000);
		return pad(utc.getFullYear(), 4)
			+ "-"
			+ pad(utc.getMonth() + 1, 2)
			+ "-"
			+ pad(utc.getDate(), 2)
			+ "T"
			+ pad(utc.getHours(), 2)
			+ ":"
			+ pad(utc.getMinutes(), 2)
			+ ":"
			+ pad(utc.getSeconds(), 2)
			+ "Z";
	}

	static function pad(value:Int, width:Int):String {
		var s = Std.string(value);
		while (s.length < width)
			s = "0" + s;
		return s;
	}
}
