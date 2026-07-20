package why.benchkit.host;

import why.benchkit.Macro;

using sys.FileSystem;
using sys.io.File;
using haxe.io.Path;
using StringTools;

/**
	Generate a static Chart.js viewer that fetches root/commit manifests and
	benchmark JSON at runtime (no embedding). Compatible with GitHub Pages
	when HTML and `--json-dir` share an origin with stable relative URLs.
**/
class HostHtml {
	function new() {}

	/**
		Write the viewer HTML (+ sibling `.css` / `.js`) to `outPath`.
		`jsonDir` must exist as a directory. `jsonBase` is the URL prefix used
		by `fetch` (trailing slash). When null, computed as the relative path
		from the HTML’s parent directory to `jsonDir`.
	**/
	public static function generate(outPath:String, jsonDir:String, ?jsonBase:String):Void {
		final outAbs = outPath.normalize();
		final jsonAbs = jsonDir.normalize();

		if (!FileSystem.exists(jsonAbs) || !FileSystem.isDirectory(jsonAbs))
			throw 'why-benchkit: not a directory: $jsonAbs';

		final outDir = outAbs.directory();
		if (outDir != null && outDir.length > 0)
			ensureDir(outDir);

		final base = switch jsonBase {
			case null | '':
				ensureTrailingSlash(relativePath(outDir == null || outDir.length == 0 ? Sys.getCwd() : outDir, jsonAbs));
			case s:
				ensureTrailingSlash(s.trim());
		};

		final stem = outAbs.withoutDirectory().withoutExtension();
		final cssName = stem + '.css';
		final jsName = stem + '.js';
		final cssAbs = Path.join([outDir == null || outDir.length == 0 ? Sys.getCwd() : outDir, cssName]);
		final jsAbs = Path.join([outDir == null || outDir.length == 0 ? Sys.getCwd() : outDir, jsName]);

		cssAbs.saveContent(renderCss());
		jsAbs.saveContent(renderJs());
		outAbs.saveContent(renderHtml(base, cssName, jsName));
	}

	/**
		Relative path from `fromDir` to `toPath` using `/` separators (URL-safe).
		Both paths should be absolute or equally rooted.
	**/
	public static function relativePath(fromDir:String, toPath:String):String {
		final fromParts = splitPath(fromDir.normalize());
		final toParts = splitPath(toPath.normalize());

		var i = 0;
		final n = fromParts.length < toParts.length ? fromParts.length : toParts.length;
		while (i < n && fromParts[i] == toParts[i])
			i++;

		final ups:Array<String> = [];
		for (_ in i...fromParts.length)
			ups.push('..');
		final downs = toParts.slice(i);
		final parts = ups.concat(downs);
		return parts.length == 0 ? '.' : parts.join('/');
	}

	static function splitPath(path:String):Array<String> {
		// Normalize separators so Windows `\` paths still produce URL-safe `/` relatives.
		final parts = path.normalize().replace('\\', '/').split('/');
		return [for (p in parts) if (p.length > 0) p];
	}

	static function ensureTrailingSlash(s:String):String {
		return s.length == 0 ? './' : s.addTrailingSlash();
	}

	static function ensureDir(path:String):Void {
		final normalized = path.normalize();
		if (normalized.exists()) {
			if (!normalized.isDirectory())
				throw 'why-benchkit: not a directory: $normalized';
			return;
		}
		final parent = Path.directory(normalized);
		if (parent != null && parent.length > 0 && parent != normalized)
			ensureDir(parent);
		normalized.createDirectory();
	}

	static function renderHtml(jsonBase:String, cssName:String, jsName:String):String {
		final escapedBase = escapeJsString(jsonBase);
		final escapedCss = escapeHtmlAttr(cssName);
		final escapedJs = escapeHtmlAttr(jsName);
		return renderTemplate('index.html', {
			escapedBase: escapedBase,
			escapedCss: escapedCss,
			escapedJs: escapedJs,
		});
	}

	static function renderCss():String {
		return renderTemplate('index.css');
	}

	static function renderJs():String {
		return renderTemplate('index.js');
	}

	static function renderTemplate(template:String, ?data:Dynamic):String {
		final template = Path.join([Macro.sourcePath().directory(), 'template/$template']);
		return new haxe.Template(template.getContent()).execute(data ?? {});
	}

	static function escapeJsString(s:String):String {
		return s.split('\\')
			.join('\\\\')
			.split('"')
			.join('\\"')
			.split('\n')
			.join('\\n')
			.split('\r')
			.join('\\r')
			.split('<')
			.join('\\u003c')
			.split('\u2028')
			.join('\\u2028')
			.split('\u2029')
			.join('\\u2029');
	}

	static function escapeHtmlAttr(s:String):String {
		return s.split('&').join('&amp;').split('"').join('&quot;').split('<').join('&lt;');
	}
}
