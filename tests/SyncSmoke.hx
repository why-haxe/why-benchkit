package;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import why.benchkit.host.HostGit;
import why.benchkit.host.HostSync;
import why.benchkit.host.JsonManifest;

/**
	HostSync additive sync smoke in a temporary git repo (interp).
**/
class SyncSmoke {
	static final BRANCH:String = 'bench-pages';
	static final DEST:String = 'bench-data';
	static final SHA_A:String = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
	static final SHA_B:String = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
	static final SHA_ONLY:String = 'cccccccccccccccccccccccccccccccccccccccc';

	static function main():Void {
		final root = Path.normalize(Path.join([Sys.getCwd(), 'dump', 'sync_smoke']));
		rmTree(root);
		FileSystem.createDirectory(root);

		final repo = Path.join([root, 'repo']);
		final source = Path.join([root, 'source']);
		FileSystem.createDirectory(repo);
		FileSystem.createDirectory(source);

		final prevCwd = Sys.getCwd();
		Sys.setCwd(repo);
		try {
			gitInitRepo();

			writeCommitFolder(Path.join([source, SHA_A]), '4.3.7', 'interp', 1000);
			writeCommitFolder(Path.join([source, '_dirty']), '4.3.7', 'interp', 9999);

			HostSync.sync(source, BRANCH, DEST, false);

			assertNoDirtyOnBranch(repo);
			assertCommitsOnBranch(repo, [SHA_A]);
			final firstHead = HostGit.gitOrFail(['rev-parse', BRANCH], repo);

			// Idempotent: second sync with same source must not create a commit.
			HostSync.sync(source, BRANCH, DEST, false);
			final secondHead = HostGit.gitOrFail(['rev-parse', BRANCH], repo);
			if (firstHead != secondHead)
				throw 'SyncSmoke: expected no commit on unchanged sync';

			// Seed a dest-only commit folder, then sync a different source set.
			seedDestOnlySha(repo);
			rmTree(source);
			FileSystem.createDirectory(source);
			writeCommitFolder(Path.join([source, SHA_A]), '4.3.7', 'node', 1000);
			writeCommitFolder(Path.join([source, SHA_B]), '4.3.7', 'js', 2000);
			writeCommitFolder(Path.join([source, '_dirty']), '4.3.7', 'js', 9999);

			HostSync.sync(source, BRANCH, DEST, false);
			assertNoDirtyOnBranch(repo);
			assertCommitsOnBranch(repo, [SHA_A, SHA_B, SHA_ONLY]);

			final nodePath = Path.join([DEST, SHA_A, '4.3.7', 'node.json']);
			HostGit.gitOrFail(['cat-file', '-e', '$BRANCH:$nodePath'], repo);
			final interpPath = Path.join([DEST, SHA_A, '4.3.7', 'interp.json']);
			final interpGone = HostGit.gitCode(['cat-file', '-e', '$BRANCH:$interpPath'], repo) != 0;
			if (!interpGone)
				throw 'SyncSmoke: expected overwritten sha folder to drop old interp.json';

			Sys.println('SyncSmoke: ok');
		} catch (e:Dynamic) {
			Sys.setCwd(prevCwd);
			throw e;
		}
		Sys.setCwd(prevCwd);
	}

	static function gitInitRepo():Void {
		HostGit.gitOrFail(['init']);
		HostGit.gitOrFail(['config', 'user.email', 'sync-smoke@example.com']);
		HostGit.gitOrFail(['config', 'user.name', 'Sync Smoke']);
		File.saveContent('README', 'sync smoke\n');
		HostGit.gitOrFail(['add', 'README']);
		HostGit.gitOrFail(['commit', '-m', 'init']);
	}

	static function seedDestOnlySha(repo:String):Void {
		final wt = Path.join([Path.directory(repo), 'seed-wt']);
		if (FileSystem.exists(wt))
			rmTree(wt);
		HostGit.gitOrFail(['worktree', 'add', wt, BRANCH], repo);
		try {
			final folder = Path.join([wt, DEST, SHA_ONLY]);
			writeCommitFolder(folder, '4.3.7', 'interp', 500);
			JsonManifest.rebuild(Path.join([wt, DEST]));
			HostGit.gitOrFail(['add', '--', DEST], wt);
			HostGit.gitOrFail(['commit', '-m', 'seed dest-only'], wt);
			HostGit.gitOrFail(['worktree', 'remove', '--force', wt], repo);
		} catch (e:Dynamic) {
			try {
				HostGit.gitOrFail(['worktree', 'remove', '--force', wt], repo);
			} catch (_:Dynamic) {}
			throw e;
		}
	}

	static function assertNoDirtyOnBranch(repo:String):Void {
		final code = HostGit.gitCode(['cat-file', '-e', '$BRANCH:$DEST/_dirty'], repo);
		if (code == 0)
			throw 'SyncSmoke: _dirty must not be synced';
	}

	static function assertCommitsOnBranch(repo:String, expected:Array<String>):Void {
		final raw = HostGit.gitOrFail(['show', '$BRANCH:$DEST/manifest.json'], repo);
		final doc:Dynamic = Json.parse(raw);
		final commits:Array<Dynamic> = doc.commits;
		if (commits.length != expected.length)
			throw 'SyncSmoke: expected ${expected.length} commits, got ${commits.length}: $commits';
		final sortedExpected = expected.copy();
		sortedExpected.sort(Reflect.compare);
		final sortedActual = [for (c in commits) Std.string(c)];
		sortedActual.sort(Reflect.compare);
		for (i in 0...sortedExpected.length) {
			if (sortedActual[i] != sortedExpected[i])
				throw 'SyncSmoke: commits mismatch: $sortedActual vs $sortedExpected';
		}
	}

	static function writeCommitFolder(folder:String, haxeVer:String, target:String, timestamp:Float):Void {
		final dir = Path.join([folder, haxeVer]);
		if (!FileSystem.exists(folder))
			FileSystem.createDirectory(folder);
		if (!FileSystem.exists(dir))
			FileSystem.createDirectory(dir);
		File.saveContent(Path.join([dir, target + '.json']), '{"ok":true,"target":"$target"}');
		JsonManifest.writeFolderManifest(folder, timestamp);
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
