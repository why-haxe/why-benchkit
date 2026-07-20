package why.benchkit.host;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
	Additively sync a local JSON tree into `--dest-dir` on `--dest-branch`
	via a temporary git worktree. Commits by default; pushes only when requested.
**/
class HostSync {
	static final DIRTY_DIR:String = '_dirty';

	function new() {}

	/**
		Copy clean commit folders from `sourceDir` into `<dest-branch>:<destDir>`,
		rebuild the root catalog, commit if the tree changed, and optionally push.
	**/
	public static function sync(sourceDir:String, destBranch:String, destDir:String, push:Bool):Void {
		final sourceAbs = Path.normalize(sourceDir);
		if (!FileSystem.exists(sourceAbs) || !FileSystem.isDirectory(sourceAbs))
			throw 'why-benchkit: not a directory: $sourceAbs';

		final branch = StringTools.trim(destBranch);
		if (branch.length == 0)
			throw 'why-benchkit: --dest-branch is required';

		final destRel = normalizeDestDir(destDir);

		final repoRoot = HostGit.gitOrFail(['rev-parse', '--show-toplevel']);
		ensureDestBranch(repoRoot, branch);

		final worktreePath = uniqueTempPath();
		var worktreeAdded = false;
		try {
			HostGit.gitOrFail(['worktree', 'add', worktreePath, branch], repoRoot);
			worktreeAdded = true;

			final destAbs = Path.normalize(Path.join([worktreePath, destRel]));
			ensureDir(destAbs);
			additiveCopy(sourceAbs, destAbs);
			JsonManifest.rebuild(destAbs);

			HostGit.gitOrFail(['add', '--', destRel], worktreePath);
			final dirty = HostGit.gitCode(['diff', '--cached', '--quiet'], worktreePath) != 0;
			if (!dirty) {
				Sys.println('why-benchkit: sync: nothing to commit on $branch ($destRel)');
				removeWorktree(repoRoot, worktreePath);
				return;
			}

			HostGit.gitOrFail(['commit', '-m', 'why-benchkit: sync $destRel'], worktreePath);
			Sys.println('why-benchkit: sync: committed on $branch ($destRel)');

			if (push) {
				HostGit.gitOrFail(['push', 'origin', 'HEAD:$branch'], worktreePath);
				Sys.println('why-benchkit: sync: pushed origin/$branch');
			}
			removeWorktree(repoRoot, worktreePath);
		} catch (e:Dynamic) {
			if (worktreeAdded)
				removeWorktree(repoRoot, worktreePath);
			else if (FileSystem.exists(worktreePath))
				rmTree(worktreePath);
			throw e;
		}
	}

	static function removeWorktree(repoRoot:String, worktreePath:String):Void {
		try {
			HostGit.gitOrFail(['worktree', 'remove', '--force', worktreePath], repoRoot);
		} catch (e:Dynamic) {
			Sys.println('why-benchkit: warning: failed to remove worktree $worktreePath ($e)');
		}
	}

	/**
		Fetch remote branch when possible; create local branch from origin or
		an empty orphan commit when the branch does not exist yet.
	**/
	static function ensureDestBranch(repoRoot:String, branch:String):Void {
		final localRef = 'refs/heads/$branch';
		final remoteRef = 'refs/remotes/origin/$branch';

		if (HostGit.gitCode(['remote', 'get-url', 'origin'], repoRoot) == 0) {
			// Best-effort fetch; missing remote branch is fine (orphan path below).
			HostGit.gitCode(['fetch', 'origin', branch], repoRoot);
		}

		if (HostGit.refExists(localRef, repoRoot))
			return;

		if (HostGit.refExists(remoteRef, repoRoot)) {
			HostGit.gitOrFail(['branch', branch, 'origin/$branch'], repoRoot);
			return;
		}

		// Empty-tree orphan first commit so `worktree add` has a ref to check out.
		final emptyTree = HostGit.gitOrFail(['hash-object', '-t', 'tree', '--stdin'], repoRoot, '');
		final commit = HostGit.gitOrFail([
			'commit-tree',
			emptyTree,
			'-m',
			'why-benchkit: init empty $branch',
		], repoRoot);
		HostGit.gitOrFail(['branch', branch, commit], repoRoot);
		Sys.println('why-benchkit: sync: created orphan branch $branch');
	}

	static function additiveCopy(sourceDir:String, destDir:String):Void {
		for (name in FileSystem.readDirectory(sourceDir)) {
			if (name == DIRTY_DIR)
				continue;
			final srcChild = Path.join([sourceDir, name]);
			if (!FileSystem.isDirectory(srcChild))
				continue;
			final destChild = Path.join([destDir, name]);
			if (FileSystem.exists(destChild))
				rmTree(destChild);
			copyTree(srcChild, destChild);
		}
	}

	static function normalizeDestDir(destDir:String):String {
		final trimmed = StringTools.trim(destDir);
		if (trimmed.length == 0)
			throw 'why-benchkit: --dest-dir is required';
		var rel = Path.normalize(trimmed);
		while (StringTools.startsWith(rel, './'))
			rel = rel.substr(2);
		if (Path.isAbsolute(rel) || rel == '..' || StringTools.startsWith(rel, '../'))
			throw 'why-benchkit: --dest-dir must be a relative path inside the dest branch: $destDir';
		if (rel == '.' || rel.length == 0)
			throw 'why-benchkit: --dest-dir must not be the branch root';
		return rel;
	}

	static function uniqueTempPath():String {
		final base = switch Sys.getEnv('TMPDIR') {
			case null | '':
				switch Sys.getEnv('TEMP') {
					case null | '':
						'/tmp';
					case t:
						t;
				};
			case t:
				t;
		};
		return Path.join([base, 'why-benchkit-sync-' + Std.string(Std.random(0x7fffffff)) + '-' + Std.string(Date.now().getTime())]);
	}

	static function ensureDir(path:String):Void {
		final normalized = Path.normalize(path);
		if (FileSystem.exists(normalized)) {
			if (!FileSystem.isDirectory(normalized))
				throw 'why-benchkit: not a directory: $normalized';
			return;
		}
		final parent = Path.directory(normalized);
		if (parent != null && parent != '' && parent != normalized && !FileSystem.exists(parent))
			ensureDir(parent);
		FileSystem.createDirectory(normalized);
	}

	static function copyTree(src:String, dest:String):Void {
		ensureDir(dest);
		for (name in FileSystem.readDirectory(src)) {
			final from = Path.join([src, name]);
			final to = Path.join([dest, name]);
			if (FileSystem.isDirectory(from))
				copyTree(from, to);
			else
				File.copy(from, to);
		}
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
