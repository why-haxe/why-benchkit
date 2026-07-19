package;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import why.benchkit.host.JsonManifest;

/**
	JsonManifest folder + root catalog smoke (interp).
**/
class ManifestSmoke {
	static function main():Void {
		final root = "dump/manifest_smoke";
		rmTree(root);
		FileSystem.createDirectory(root);

		final shaOld = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
		final shaNew = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
		final dirty = Path.join([root, "_dirty"]);

		writeResult(Path.join([root, shaOld]), "4.3.7", "interp");
		JsonManifest.writeFolderManifest(Path.join([root, shaOld]), 1000);

		writeResult(Path.join([root, shaNew]), "4.3.7", "node");
		JsonManifest.writeFolderManifest(Path.join([root, shaNew]), 2000);

		writeResult(dirty, "4.3.7", "interp");
		JsonManifest.writeFolderManifest(dirty, 9999);

		JsonManifest.rebuild(root);

		final rootDoc:Dynamic = Json.parse(File.getContent(Path.join([root, "manifest.json"])));
		final commits:Array<Dynamic> = rootDoc.commits;
		if (commits.length != 2)
			throw 'ManifestSmoke: expected 2 clean commits, got ${commits.length}';
		if (commits[0] != shaOld || commits[1] != shaNew)
			throw 'ManifestSmoke: commits order wrong: $commits';

		final oldManifest:Dynamic = Json.parse(File.getContent(Path.join([root, shaOld, "manifest.json"])));
		final oldFiles:Array<Dynamic> = oldManifest.files;
		if (oldFiles.length != 1 || oldFiles[0] != "4.3.7/interp.json")
			throw 'ManifestSmoke: unexpected files for old sha: $oldFiles';

		// Idempotent rebuild
		final first = File.getContent(Path.join([root, "manifest.json"]));
		JsonManifest.rebuild(root);
		final second = File.getContent(Path.join([root, "manifest.json"]));
		if (first != second)
			throw "ManifestSmoke: rebuild is not idempotent";

		Sys.println("ManifestSmoke: ok");
	}

	static function writeResult(folder:String, haxeVer:String, target:String):Void {
		final dir = Path.join([folder, haxeVer]);
		if (!FileSystem.exists(folder))
			FileSystem.createDirectory(folder);
		if (!FileSystem.exists(dir))
			FileSystem.createDirectory(dir);
		File.saveContent(Path.join([dir, target + ".json"]), '{"ok":true}');
	}

	static function rmTree(path:String):Void {
		if (!FileSystem.exists(path))
			return;
		if (FileSystem.isDirectory(path)) {
			for (name in FileSystem.readDirectory(path))
				rmTree(Path.join([path, name]));
			FileSystem.deleteDirectory(path);
		} else {
			FileSystem.deleteFile(path);
		}
	}
}
