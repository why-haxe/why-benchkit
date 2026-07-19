package why.benchkit.host;

/**
	`why-benchkit html` subcommand: generate a static Chart.js viewer that fetches
	root/commit manifests and benchmark JSON at runtime (no embedding).

	Local preview requires a static file server (`file://` fetch will fail).
	Deploy the HTML and `--json-dir` under the same origin; relative URLs are
	computed from the HTML location to `--json-dir` unless `--json-base` is set.
**/
@:alias(false)
class HostHtmlCommand {
	/**
		Output HTML path (required), e.g. `bin/out.html`
	**/
	@:flag('out')
	@:alias(false)
	@:optional
	public var out:String;

	/**
		JSON output tree root (required). Must contain `manifest.json` (and
		optionally commit / `_dirty` folders) for the viewer to load.
	**/
	@:flag('json-dir')
	@:alias(false)
	@:optional
	public var jsonDir:String;

	/**
		Optional URL prefix for `fetch` (trailing slash added if missing).
		Overrides the default relative path from the HTML file to `--json-dir`.
		Use when deploy layout differs from the local filesystem layout.
	**/
	@:flag('json-base')
	@:alias(false)
	@:optional
	public var jsonBase:String;

	public function new() {}

	/**
		Generate a static Chart.js HTML viewer (+ sibling CSS/JS) that loads
		manifests and result JSON via `fetch`. Requires HTTP (e.g. `npx serve`
		/ `python -m http.server`); `file://` will not work.
	**/
	@:defaultCommand
	public function run():Void {
		try {
			final outPath = requiredPath(out, '--out');
			final dir = requiredPath(jsonDir, '--json-dir');
			if (!sys.FileSystem.exists(dir) || !sys.FileSystem.isDirectory(dir)) {
				Sys.println('why-benchkit: not a directory: $dir');
				Sys.exit(1);
				return;
			}
			final base = switch jsonBase {
				case null | '':
					null;
				case s:
					final trimmed = StringTools.trim(s);
					trimmed.length == 0 ? null : trimmed;
			};
			HostHtml.generate(outPath, dir, base);
			final stem = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(outPath));
			Sys.println('why-benchkit: wrote $outPath (+ $stem.css / $stem.js)');
			Sys.println('why-benchkit: preview with a static server (not file://), e.g. npx serve or python -m http.server');
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
		Sys.println(tink.Cli.getDoc(this, new tink.cli.doc.DefaultFormatter('why-benchkit html')));
	}

	static function requiredPath(value:Null<String>, flag:String):String {
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
		return haxe.io.Path.normalize(absolutePath(raw));
	}

	static function absolutePath(path:String):String {
		if (haxe.io.Path.isAbsolute(path))
			return path;
		return haxe.io.Path.join([Sys.getCwd(), path]);
	}
}
