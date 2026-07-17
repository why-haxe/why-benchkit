package why.benchkit;

/**
	UTC ISO-8601 timestamps (`YYYY-MM-DDTHH:MM:SSZ`) for suite JSON.
**/
class UtcIso {
	function new() {}

	public static function now():String {
		return format(Date.now());
	}

	public static function format(date:Date):String {
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
