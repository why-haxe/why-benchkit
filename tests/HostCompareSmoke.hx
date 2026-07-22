import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import why.benchkit.host.HostCompare;
import why.benchkit.host.HostGit;
import why.benchkit.host.Targets;

/**
	HostCompare run-at-SHA smoke: temp consumer git repo (fixture-shaped),
	OS-temp json-dir, worktree + lix + HostRun for two SHAs.
	Usage: haxe hostcompare.hxml
**/
class HostCompareSmoke {
	static function main():Void {
		final libraryRoot = Path.normalize(Sys.getCwd());
		final originalCwd = libraryRoot;
		final targets:Targets = 'interp';

		assertResolveFails();
		assertJsonDirIsOsTemp();

		final prepared = prepareConsumerRepo(libraryRoot);
		Sys.setCwd(prepared.repo);
		try {
			final worktreesBefore = listWorktrees(prepared.repo);

			HostCompare.withRuns(prepared.baseSha, prepared.headSha, targets, libraryRoot, 1, artifacts -> {
				assertShaFolder(artifacts.jsonDir, artifacts.baseSha);
				assertShaFolder(artifacts.jsonDir, artifacts.headSha);
				if (artifacts.baseSha != prepared.baseSha || artifacts.headSha != prepared.headSha)
					throw 'HostCompareSmoke: artifact SHAs mismatch';
				Sys.println('HostCompareSmoke: json under ${artifacts.jsonDir}');
				Sys.println('  base ${artifacts.baseSha}');
				Sys.println('  head ${artifacts.headSha}');
				return true;
			});

			final worktreesAfter = listWorktrees(prepared.repo);
			assertNoCompareWorktreesLeft(worktreesBefore, worktreesAfter);
		} catch (e:Dynamic) {
			Sys.setCwd(originalCwd);
			rmTree(prepared.root);
			throw e;
		}
		Sys.setCwd(originalCwd);
		rmTree(prepared.root);

		if (Path.normalize(Sys.getCwd()) != Path.normalize(originalCwd))
			throw 'HostCompareSmoke: cwd not restored (got ${Sys.getCwd()}, expected $originalCwd)';

		Sys.println('HostCompareSmoke ok');
	}

	/**
		Build a tiny git consumer from `fixture/foo` so worktrees include
		scoped `haxe_libraries` (root repo's travix.hxml is gitignored).
	**/
	static function prepareConsumerRepo(libraryRoot:String):PreparedRepo {
		final root = uniqueTempDir('why-benchkit-compare-smoke-');
		final repo = Path.join([root, 'repo']);
		final fixture = Path.join([libraryRoot, 'fixture', 'foo']);
		if (!FileSystem.exists(Path.join([fixture, 'bench.hxml'])))
			throw 'HostCompareSmoke: missing fixture at $fixture';

		copyTree(fixture, repo);
		writeWhyBenchkitLib(repo, libraryRoot);
		writeFastSuite(repo);

		HostGit.gitOrFail(['init'], repo);
		HostGit.gitOrFail(['config', 'user.email', 'compare-smoke@example.com'], repo);
		HostGit.gitOrFail(['config', 'user.name', 'Compare Smoke'], repo);
		HostGit.gitOrFail(['add', '-A'], repo);
		HostGit.gitOrFail(['commit', '-m', 'base suite'], repo);
		final baseSha = HostGit.gitOrFail(['rev-parse', 'HEAD'], repo);

		File.saveContent(Path.join([repo, 'COMPARE_SMOKE_MARKER']), 'head\n');
		HostGit.gitOrFail(['add', 'COMPARE_SMOKE_MARKER'], repo);
		HostGit.gitOrFail(['commit', '-m', 'head marker'], repo);
		final headSha = HostGit.gitOrFail(['rev-parse', 'HEAD'], repo);

		if (baseSha == headSha)
			throw 'HostCompareSmoke: expected distinct base/head SHAs';

		return {
			root: root,
			repo: repo,
			baseSha: baseSha,
			headSha: headSha,
		};
	}

	static function writeWhyBenchkitLib(repo:String, libraryRoot:String):Void {
		final src = Path.normalize(Path.join([libraryRoot, 'src']));
		final content = [
			'# HostCompareSmoke: point why-benchkit at the library under test',
			'-cp $src',
			'-lib travix',
			'-lib hx3compat',
			'-lib why-unit',
			'-D why-benchkit=0.0.1',
			'-D no-deprecation-warnings',
		].join('\n') + '\n';
		File.saveContent(Path.join([repo, 'haxe_libraries', 'why-benchkit.hxml']), content);
	}

	/** Fixed tiny suite so travix interp stays quick under sampleCount=1. */
	static function writeFastSuite(repo:String):Void {
		final src = [
			'import why.benchkit.Runner;',
			'',
			'class Bench {',
			'\tpublic static function main():Void {',
			'\t\tRunner.run([new CompareSmokeSuite()]);',
			'\t}',
			'}',
			'',
			'@:name("compare_smoke")',
			'class CompareSmokeSuite {',
			'\tpublic function new() {}',
			'',
			'\t@:name("sum.loop")',
			'\t@:warmup(5)',
			'\t@:iterations(200)',
			'\tpublic function sumLoop():Int {',
			'\t\tvar sum = 0;',
			'\t\tfor (i in 0...50) sum += i;',
			'\t\treturn sum;',
			'\t}',
			'}',
			'',
		].join('\n');
		File.saveContent(Path.join([repo, 'src', 'Bench.hx']), src);
	}

	static function assertResolveFails():Void {
		try {
			HostCompare.resolveSha('definitely-not-a-real-ref-zzzz');
			throw 'HostCompareSmoke: expected resolveSha to fail';
		} catch (e:Dynamic) {
			final msg = Std.string(e);
			if (msg.indexOf('could not resolve') < 0)
				throw 'HostCompareSmoke: unexpected resolve error: $msg';
			Sys.println('HostCompareSmoke resolve failure ok');
		}
	}

	static function assertJsonDirIsOsTemp():Void {
		final dir = HostCompare.createJsonDir();
		try {
			final tmp = switch Sys.getEnv('TMPDIR') {
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
			final normalizedTmp = Path.normalize(tmp);
			final normalizedDir = Path.normalize(dir);
			if (!StringTools.startsWith(normalizedDir, normalizedTmp))
				throw 'HostCompareSmoke: json-dir not under OS temp: $normalizedDir (tmp=$normalizedTmp)';
			if (normalizedDir.indexOf('why-benchkit-compare-') < 0)
				throw 'HostCompareSmoke: unexpected json-dir name: $normalizedDir';
			Sys.println('HostCompareSmoke OS-temp json-dir ok ($normalizedDir)');
		} catch (e:Dynamic) {
			HostCompare.removeJsonDir(dir);
			throw e;
		}
		HostCompare.removeJsonDir(dir);
	}

	static function assertShaFolder(jsonDir:String, fullSha:String):Void {
		final path = Path.join([jsonDir, fullSha]);
		if (!FileSystem.exists(path) || !FileSystem.isDirectory(path))
			throw 'HostCompareSmoke: missing SHA folder $path';
		final dirty = Path.join([jsonDir, '_dirty']);
		if (FileSystem.exists(dirty))
			throw 'HostCompareSmoke: unexpected _dirty under $jsonDir';
		if (!hasJsonFile(path))
			throw 'HostCompareSmoke: no JSON under $path (expected <sha>/<haxeVer>/<target>.json)';
	}

	static function hasJsonFile(dir:String):Bool {
		for (name in FileSystem.readDirectory(dir)) {
			final child = Path.join([dir, name]);
			if (FileSystem.isDirectory(child)) {
				if (hasJsonFile(child))
					return true;
			} else if (StringTools.endsWith(name, '.json') && name != 'manifest.json')
				return true;
		}
		return false;
	}

	static function listWorktrees(repoRoot:String):Array<String> {
		final raw = HostGit.gitOrFail(['worktree', 'list', '--porcelain'], repoRoot);
		final paths:Array<String> = [];
		for (line in raw.split('\n')) {
			if (StringTools.startsWith(line, 'worktree '))
				paths.push(StringTools.trim(line.substr('worktree '.length)));
		}
		return paths;
	}

	static function assertNoCompareWorktreesLeft(before:Array<String>, after:Array<String>):Void {
		for (path in after) {
			if (before.indexOf(path) >= 0)
				continue;
			if (path.indexOf('why-benchkit-compare-wt-') >= 0)
				throw 'HostCompareSmoke: leftover compare worktree: $path';
		}
		Sys.println('HostCompareSmoke worktree cleanup ok');
	}

	static function uniqueTempDir(prefix:String):String {
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
		final path = Path.normalize(Path.join([
			base,
			prefix + Std.string(Std.random(0x7fffffff)) + '-' + Std.string(Date.now().getTime()),
		]));
		FileSystem.createDirectory(path);
		return path;
	}

	static function copyTree(src:String, dest:String):Void {
		ensureDir(dest);
		for (name in FileSystem.readDirectory(src)) {
			if (name == 'bench-out' || name == 'bench-viewer' || name == 'bin')
				continue;
			final from = Path.join([src, name]);
			final to = Path.join([dest, name]);
			if (FileSystem.isDirectory(from))
				copyTree(from, to);
			else
				File.copy(from, to);
		}
	}

	static function ensureDir(path:String):Void {
		final normalized = Path.normalize(path);
		if (FileSystem.exists(normalized)) {
			if (!FileSystem.isDirectory(normalized))
				throw 'HostCompareSmoke: not a directory: $normalized';
			return;
		}
		final parent = Path.directory(normalized);
		if (parent != null && parent != '' && parent != normalized && !FileSystem.exists(parent))
			ensureDir(parent);
		FileSystem.createDirectory(normalized);
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

typedef PreparedRepo = {
	final root:String;
	final repo:String;
	final baseSha:String;
	final headSha:String;
}
