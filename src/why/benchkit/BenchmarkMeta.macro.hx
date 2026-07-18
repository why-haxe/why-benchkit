package why.benchkit;

import haxe.macro.Expr;

class BenchmarkMeta {
	public static function gitHash():Expr {
		final hash = git(["rev-parse", "HEAD"]);
		final porcelain = git(["status", "--porcelain"]);
		final dirty = porcelain != null && porcelain.length > 0;
		final value = switch [hash, dirty] {
			case [null, _]: null;
			case [_, true]: hash + "-dirty";
			case [_, false]: hash;
		}
		return macro $v{value};
	}

	static function git(args:Array<String>):Null<String> {
		try {
			final process = new sys.io.Process("git", args);
			final out = StringTools.trim(process.stdout.readAll().toString());
			final code = process.exitCode();
			process.close();
			if (code != 0)
				return null;
			return out;
		} catch (e:Dynamic) {
			return null;
		}
	}
}
