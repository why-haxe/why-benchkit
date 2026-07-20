package why.benchkit.host;

/**
	Runtime git probes for host JSON output paths (clean SHA vs `_dirty`),
	plus throwing helpers for `sync`.
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

	/**
		Soft probe: returns trimmed stdout, or `null` on failure / missing git.
	**/
	static function git(args:Array<String>):Null<String> {
		return switch run(args, null, null) {
			case {code: 0, stdout: out}:
				out;
			case _:
				null;
		};
	}

	/**
		Run `git` with optional `cwd` / stdin. Throws on non-zero exit.
		Returns trimmed stdout.
	**/
	public static function gitOrFail(args:Array<String>, ?cwd:String, ?stdin:String):String {
		final result = run(args, cwd, stdin);
		if (result.code != 0) {
			final detail = result.stderr.length > 0 ? result.stderr : result.stdout;
			throw 'why-benchkit: git ${args.join(" ")} failed (exit ${result.code})${detail.length > 0 ? ": " + detail : ""}';
		}
		return result.stdout;
	}

	/**
		Run `git`; returns exit code (does not throw). Optional `cwd`.
	**/
	public static function gitCode(args:Array<String>, ?cwd:String):Int {
		return run(args, cwd, null).code;
	}

	/**
		True when `ref` resolves (e.g. `refs/heads/gh-pages`, `refs/remotes/origin/gh-pages`).
	**/
	public static function refExists(ref:String, ?cwd:String):Bool {
		return gitCode(['show-ref', '--verify', '--quiet', ref], cwd) == 0;
	}

	static function run(args:Array<String>, cwd:Null<String>, stdin:Null<String>):GitRunResult {
		try {
			// `git -C <cwd> …` — portable cwd without relying on Process cwd support.
			final full = cwd == null ? args : ['-C', cwd].concat(args);
			final process = new sys.io.Process('git', full);
			if (stdin != null) {
				process.stdin.writeString(stdin);
				process.stdin.close();
			}
			final out = StringTools.trim(process.stdout.readAll().toString());
			final err = StringTools.trim(process.stderr.readAll().toString());
			final code = process.exitCode();
			process.close();
			return {code: code, stdout: out, stderr: err};
		} catch (e:Dynamic) {
			return {code: 1, stdout: '', stderr: Std.string(e)};
		}
	}
}

typedef HostJsonOutput = {
	final folderId:String;
	final path:String;
	final timestamp:Float;
	final dirty:Bool;
}

typedef GitRunResult = {
	final code:Int;
	final stdout:String;
	final stderr:String;
}
