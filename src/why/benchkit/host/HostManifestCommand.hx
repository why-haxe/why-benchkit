package why.benchkit.host;

/**
	`why-benchkit manifest` subcommand: rebuild the root clean-commit catalog
	under `--json-dir` from on-disk commit manifests.
**/
@:alias(false)
class HostManifestCommand {
	/**
		JSON output tree root (required). Scans child commit dirs, skips `_dirty`,
		rewrites `<json-dir>/manifest.json`.
	**/
	@:flag('json-dir')
	@:alias(false)
	@:optional
	public var jsonDir:String;

	public function new() {}

	/**
		Rebuild `<json-dir>/manifest.json` from commit folder manifests on disk.
		Idempotent: same tree → same catalog.
	**/
	@:defaultCommand
	public function run():Void {
		try {
			final dir = switch jsonDir {
				case null | '':
					null;
				case s:
					final trimmed = StringTools.trim(s);
					if (trimmed.length == 0)
						null;
					else
						haxe.io.Path.normalize(absolutePath(trimmed));
			};
			if (dir == null) {
				Sys.println('why-benchkit: --json-dir is required');
				Sys.exit(1);
				return;
			}
			if (!sys.FileSystem.exists(dir) || !sys.FileSystem.isDirectory(dir)) {
				Sys.println('why-benchkit: not a directory: $dir');
				Sys.exit(1);
				return;
			}
			JsonManifest.rebuild(dir);
			Sys.println('why-benchkit: wrote ${haxe.io.Path.join([dir, "manifest.json"])}');
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
		Sys.println(tink.Cli.getDoc(this, new tink.cli.doc.DefaultFormatter('why-benchkit manifest')));
	}

	static function absolutePath(path:String):String {
		if (haxe.io.Path.isAbsolute(path))
			return path;
		return haxe.io.Path.join([Sys.getCwd(), path]);
	}
}
