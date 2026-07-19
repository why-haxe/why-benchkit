package why.benchkit.host;

/**
	Runtime git probes for host JSON output paths (clean SHA vs `_dirty`).
**/
class HostGit {
	function new() {}

	/**
		Resolve where JSON results should land under `jsonDir`.

		- Clean HEAD → `<jsonDir>/<full-sha>`, timestamp = git committer time (ms)
		- Dirty working tree, missing git, or unresolvable HEAD → `<jsonDir>/_dirty`,
		  timestamp = `Date.now()` (caller may refresh at write time)
	**/
	public static function resolveOutput(jsonDir:String):HostJsonOutput {
		final hash = git(['rev-parse', 'HEAD']);
		final porcelain = git(['status', '--porcelain']);
		final dirty = porcelain == null || porcelain.length > 0;

		if (hash == null || dirty) {
			return {
				folderId: '_dirty',
				path: haxe.io.Path.join([jsonDir, '_dirty']),
				timestamp: Date.now().getTime(),
				dirty: true,
			};
		}

		final commitSeconds = git(['show', '-s', '--format=%ct', 'HEAD']);
		final timestamp = switch commitSeconds {
			case null:
				Date.now().getTime();
			case s:
				final secs = Std.parseFloat(s);
				if (Math.isNaN(secs))
					Date.now().getTime();
				else
					secs * 1000;
		};

		return {
			folderId: hash,
			path: haxe.io.Path.join([jsonDir, hash]),
			timestamp: timestamp,
			dirty: false,
		};
	}

	static function git(args:Array<String>):Null<String> {
		try {
			final process = new sys.io.Process('git', args);
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

typedef HostJsonOutput = {
	final folderId:String;
	final path:String;
	final timestamp:Float;
	final dirty:Bool;
}
