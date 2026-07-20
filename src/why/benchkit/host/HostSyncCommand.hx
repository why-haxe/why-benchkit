package why.benchkit.host;

/**
	`why-benchkit sync` subcommand: additively copy a local JSON tree into
	`--dest-dir` on `--dest-branch` (temporary worktree), commit by default,
	push only with `--push`.
**/
@:alias(false)
class HostSyncCommand {
	/**
		Local JSON tree to copy from (required). Clean commit folders only;
		`_dirty` is never synced.
	**/
	@:flag('source-dir')
	@:alias(false)
	@:optional
	public var sourceDir:String;

	/**
		Git branch that receives the synced tree (required). Created as an
		orphan empty branch when missing.
	**/
	@:flag('dest-branch')
	@:alias(false)
	@:optional
	public var destBranch:String;

	/**
		Path inside `--dest-branch` for the JSON tree (required), e.g. `bench-data/`.
		Must be relative to the branch root.
	**/
	@:flag('dest-dir')
	@:alias(false)
	@:optional
	public var destDir:String;

	/**
		Also `git push origin <dest-branch>` after a successful commit.
	**/
	@:flag('push')
	@:alias(false)
	public var push:Bool = false;

	public function new() {}

	/**
		Additively sync `--source-dir` into `--dest-dir` on `--dest-branch`,
		rebuild the root catalog, commit if changed, and optionally push.
	**/
	@:defaultCommand
	public function run():Void {
		try {
			final source = requiredPath(sourceDir, '--source-dir');
			final branch = requiredString(destBranch, '--dest-branch');
			final dest = requiredString(destDir, '--dest-dir');
			if (!sys.FileSystem.exists(source) || !sys.FileSystem.isDirectory(source)) {
				Sys.println('why-benchkit: not a directory: $source');
				Sys.exit(1);
				return;
			}
			HostSync.sync(source, branch, dest, push);
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
		Sys.println(tink.Cli.getDoc(this, new tink.cli.doc.DefaultFormatter('why-benchkit sync')));
	}

	static function requiredPath(value:Null<String>, flag:String):String {
		final raw = requiredString(value, flag);
		return haxe.io.Path.normalize(absolutePath(raw));
	}

	static function requiredString(value:Null<String>, flag:String):String {
		final raw = switch value {
			case null | '':
				null;
			case s:
				final trimmed = StringTools.trim(s);
				trimmed.length == 0 ? null : trimmed;
		};
		if (raw == null) {
			Sys.println('why-benchkit: $flag is required');
			Sys.exit(1);
			return '';
		}
		return raw;
	}

	static function absolutePath(path:String):String {
		if (haxe.io.Path.isAbsolute(path))
			return path;
		return haxe.io.Path.join([Sys.getCwd(), path]);
	}
}
