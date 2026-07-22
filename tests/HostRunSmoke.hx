import haxe.io.Path;
import sys.FileSystem;
import why.benchkit.host.HostRun;
import why.benchkit.host.HostRunStatus;
import why.benchkit.host.Targets;

/**
	HostRun status smoke: returns Failed/Ok without Sys.exit so the shared
	runner can be invoked twice in one process (compare orchestration).
	Usage: haxe hostrun.hxml
**/
class HostRunSmoke {
	static function main():Void {
		final originalCwd = Sys.getCwd();
		final targets:Targets = 'interp';
		try {
			assertFailedTwice(originalCwd, targets);
			assertOkTwice(originalCwd, targets);
			Sys.println('HostRunSmoke ok');
		} catch (e:Dynamic) {
			Sys.setCwd(originalCwd);
			throw e;
		}
		Sys.setCwd(originalCwd);
	}

	/** Missing bench.hxml → Failed, and a second call still returns (no Sys.exit). */
	static function assertFailedTwice(libraryRoot:String, targets:Targets):Void {
		final tmp = uniqueTempDir();
		FileSystem.createDirectory(tmp);
		try {
			Sys.setCwd(tmp);

			final first = HostRun.run(targets, libraryRoot, null, 1);
			if (first != Failed)
				throw 'HostRunSmoke: expected Failed without bench.hxml, got $first';

			final second = HostRun.run(targets, libraryRoot, null, 1);
			if (second != Failed)
				throw 'HostRunSmoke: second Failed invoke expected Failed, got $second';

			Sys.println('HostRunSmoke Failed path ok (status=$first then $second)');
		} catch (e:Dynamic) {
			Sys.setCwd(libraryRoot);
			rmTree(tmp);
			throw e;
		}
		Sys.setCwd(libraryRoot);
		rmTree(tmp);
	}

	/**
		Happy path through travix interp: HostRun returns Ok twice in one process
		(acceptance: compare can run base then head when travix does not hard-exit).
	**/
	static function assertOkTwice(libraryRoot:String, targets:Targets):Void {
		final fixture = Path.normalize(Path.join([libraryRoot, 'fixture', 'foo']));
		final benchHxml = Path.join([fixture, 'bench.hxml']);
		if (!FileSystem.exists(benchHxml))
			throw 'HostRunSmoke: missing fixture suite at $benchHxml';

		Sys.setCwd(fixture);

		final first = HostRun.run(targets, libraryRoot, null, 1);
		if (first != Ok)
			throw 'HostRunSmoke: expected Ok on fixture, got $first';

		final second = HostRun.run(targets, libraryRoot, null, 1);
		if (second != Ok)
			throw 'HostRunSmoke: second Ok invoke expected Ok, got $second';

		Sys.println('HostRunSmoke Ok path ok (status=$first then $second)');
		Sys.setCwd(libraryRoot);
	}

	static function uniqueTempDir():String {
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
		return Path.normalize(Path.join([base, 'why-benchkit-hostrun-smoke-' + Std.string(Date.now().getTime())]));
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
