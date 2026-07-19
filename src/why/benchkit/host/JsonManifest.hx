package why.benchkit.host;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
	Commit / dirty folder `manifest.json` and root clean-commit catalog.

	Commit / dirty shape: `{ "timestamp": <ms>, "files": ["4.3.7/node.json", ...] }`
	Root shape: `{ "commits": ["<full-sha>", ...] }` ordered oldest → newest by
	each `<id>/manifest.json` `timestamp`. `_dirty` is never listed in the root.
**/
class JsonManifest {
	static final MANIFEST_NAME:String = 'manifest.json';
	static final DIRTY_DIR:String = '_dirty';

	function new() {}

	/**
		Write / overwrite `<folder>/manifest.json` with `timestamp` and a refreshed
		`files` list of result JSON paths relative to `folder` (excludes
		`manifest.json` itself).
	**/
	public static function writeFolderManifest(folder:String, timestamp:Float):Void {
		final normalized = Path.normalize(folder);
		if (!FileSystem.exists(normalized) || !FileSystem.isDirectory(normalized))
			throw 'why-benchkit: not a directory: $normalized';

		final files = listResultFiles(normalized);
		final doc:CommitManifestDoc = {
			timestamp: timestamp,
			files: files,
		};
		File.saveContent(Path.join([normalized, MANIFEST_NAME]), Json.stringify(doc, '  ') + '\n');
	}

	/**
		Idempotent root catalog rebuild: scan child dirs of `jsonDir`, skip
		`_dirty` and non-dirs, sort by each folder's commit-manifest `timestamp`,
		rewrite `<jsonDir>/manifest.json` with clean commit ids only.
	**/
	public static function rebuild(jsonDir:String):Void {
		final normalized = Path.normalize(jsonDir);
		if (!FileSystem.exists(normalized) || !FileSystem.isDirectory(normalized))
			throw 'why-benchkit: not a directory: $normalized';

		final entries:Array<{id:String, timestamp:Float}> = [];
		for (name in FileSystem.readDirectory(normalized)) {
			if (name == DIRTY_DIR || name == MANIFEST_NAME)
				continue;
			final child = Path.join([normalized, name]);
			if (!FileSystem.isDirectory(child))
				continue;
			final ts = readFolderTimestamp(child);
			if (ts == null)
				continue;
			entries.push({id: name, timestamp: ts});
		}

		entries.sort((a, b) -> {
			final cmp = Reflect.compare(a.timestamp, b.timestamp);
			return cmp != 0 ? cmp : Reflect.compare(a.id, b.id);
		});

		final doc:RootManifestDoc = {
			commits: [for (e in entries) e.id],
		};
		File.saveContent(Path.join([normalized, MANIFEST_NAME]), Json.stringify(doc, '  ') + '\n');
	}

	static function readFolderTimestamp(folder:String):Null<Float> {
		final path = Path.join([folder, MANIFEST_NAME]);
		if (!FileSystem.exists(path) || FileSystem.isDirectory(path))
			return null;
		try {
			final raw:Dynamic = Json.parse(File.getContent(path));
			final ts:Dynamic = Reflect.field(raw, 'timestamp');
			if (ts == null)
				return null;
			if (Std.isOfType(ts, Float) || Std.isOfType(ts, Int))
				return (ts : Float);
			return null;
		} catch (e:Dynamic) {
			return null;
		}
	}

	/**
		Collect result `.json` paths under `folder`, relative to `folder`.
		Skips `manifest.json` at any depth. Relative paths always use `/`
		(portable for the static viewer / GitHub Pages).
	**/
	static function listResultFiles(folder:String):Array<String> {
		final files:Array<String> = [];
		function walk(relParts:Array<String>):Void {
			final abs = Path.join([folder].concat(relParts));
			for (name in FileSystem.readDirectory(abs)) {
				final childParts = relParts.concat([name]);
				final childAbs = Path.join([folder].concat(childParts));
				if (FileSystem.isDirectory(childAbs)) {
					walk(childParts);
					continue;
				}
				if (name == MANIFEST_NAME)
					continue;
				if (StringTools.endsWith(name, '.json'))
					files.push(childParts.join('/'));
			}
		}
		walk([]);
		files.sort(Reflect.compare);
		return files;
	}
}

typedef CommitManifestDoc = {
	final timestamp:Float;
	final files:Array<String>;
}

typedef RootManifestDoc = {
	final commits:Array<String>;
}
