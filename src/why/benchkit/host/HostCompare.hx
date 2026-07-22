package why.benchkit.host;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import why.benchkit.BenchmarkResult;
import why.benchkit.Compare;
import why.benchkit.CompareEntry;
import why.benchkit.CompareReport;
import why.benchkit.CompareVerdict;
import why.benchkit.MeasureResult;
import why.benchkit.SuiteResult;
import why.benchkit.host.HostRunStatus;
import why.unit.time.Millisecond;

/**
	Compare orchestration helpers: resolve SHAs, OS-temp `json-dir`, per-SHA
	worktree + `lix download` + shared `HostRun`, load JSON, then cleanup.

	Callers own process exit; prefer `withRuns` so the temp `json-dir` is
	removed after results are consumed.
**/
class HostCompare {
	function new() {}

	/**
		Resolve `ref` (full/short SHA or branch/tag) to a full commit hash.
		Fails clearly when the ref is missing or ambiguous.
	**/
	public static function resolveSha(ref:String, ?cwd:String):String {
		final trimmed = StringTools.trim(ref);
		if (trimmed.length == 0)
			throw 'why-benchkit: empty SHA/ref';
		try {
			return HostGit.gitOrFail(['rev-parse', '--verify', trimmed + '^{commit}'], cwd);
		} catch (e:Dynamic) {
			throw 'why-benchkit: could not resolve SHA/ref "$trimmed" ($e)';
		}
	}

	/**
		Create a unique OS-temp directory for compare JSON output.
		Must stay outside the consumer repo and any worktrees.
	**/
	public static function createJsonDir():String {
		final path = uniqueTempPath('why-benchkit-compare-');
		ensureDir(path);
		return path;
	}

	/** Best-effort recursive delete of a compare `json-dir`. */
	public static function removeJsonDir(jsonDir:String):Void {
		try {
			rmTree(jsonDir);
		} catch (e:Dynamic) {
			Sys.println('why-benchkit: warning: failed to remove json-dir $jsonDir ($e)');
		}
	}

	/**
		Checkout `shaOrRef` in an OS-temp worktree, run `lix download`, invoke
		`HostRun` with `jsonDir` / `sampleCount`, assert clean `<jsonDir>/<fullSha>/`,
		then remove the worktree (best-effort).

		Restores the caller cwd. Does not delete `jsonDir` (shared across SHAs).
		Returns the resolved full SHA.
	**/
	public static function runAtSha(
		shaOrRef:String,
		jsonDir:String,
		targets:Targets,
		libraryRoot:String,
		sampleCount:Int = 5
	):String {
		if (sampleCount < 1)
			throw 'why-benchkit: sampleCount must be >= 1';

		// Absolutize before switching cwd into the worktree so a relative
		// `jsonDir` still resolves outside the checkout.
		final jsonDirAbs = absolutePath(jsonDir);
		if (jsonDirAbs.length == 0)
			throw 'why-benchkit: json-dir is required';
		ensureDir(jsonDirAbs);

		final repoRoot = HostGit.gitOrFail(['rev-parse', '--show-toplevel']);
		final fullSha = resolveSha(shaOrRef, repoRoot);

		final worktreePath = uniqueTempPath('why-benchkit-compare-wt-');
		var worktreeAdded = false;
		final originalCwd = Sys.getCwd();

		try {
			HostGit.gitOrFail(['worktree', 'add', '--detach', worktreePath, fullSha], repoRoot);
			worktreeAdded = true;

			Sys.setCwd(worktreePath);
			lixDownload(worktreePath);

			Sys.println('why-benchkit: compare: running at $fullSha');
			final status = HostRun.run(targets, libraryRoot, jsonDirAbs, sampleCount);
			if (status != HostRunStatus.Ok)
				throw 'why-benchkit: HostRun failed at $fullSha (status=$status)';

			assertCleanShaFolder(jsonDirAbs, fullSha);

			Sys.setCwd(originalCwd);
			removeWorktree(repoRoot, worktreePath);
			return fullSha;
		} catch (e:Dynamic) {
			try {
				Sys.setCwd(originalCwd);
			} catch (ignore:Dynamic) {}
			if (worktreeAdded)
				removeWorktree(repoRoot, worktreePath);
			else if (FileSystem.exists(worktreePath))
				rmTree(worktreePath);
			throw e;
		}
	}

	/**
		Create OS-temp `json-dir`, run suite at `--base` then `--head` into it,
		invoke `use` with artifacts, and always delete `json-dir` on the way out.

		Worktrees are removed inside each `runAtSha`. Prefer this from CLI/smoke
		so temp JSON does not leak when the stack still unwinds (cleanup on both
		success and failure paths; OS temp remains the crash / Sys.exit safety net).
	**/
	public static function withRuns<T>(
		base:String,
		head:String,
		targets:Targets,
		libraryRoot:String,
		sampleCount:Int,
		use:(artifacts:HostCompareArtifacts) -> T
	):T {
		final baseSha = resolveSha(base);
		final headSha = resolveSha(head);
		final jsonDir = createJsonDir();
		try {
			runAtSha(baseSha, jsonDir, targets, libraryRoot, sampleCount);
			runAtSha(headSha, jsonDir, targets, libraryRoot, sampleCount);
			final result = use({
				jsonDir: jsonDir,
				baseSha: baseSha,
				headSha: headSha,
			});
			removeJsonDir(jsonDir);
			return result;
		} catch (e:Dynamic) {
			removeJsonDir(jsonDir);
			throw e;
		}
	}

	/**
		Load all result JSON under `<jsonDir>/<fullSha>/…`.

		Sets each `BenchmarkResult.target` from the filename stem (CLI/host
		target, e.g. `interp`), **not** the raw JSON body `target` (often
		`eval` for `--interp`).
	**/
	public static function loadDocs(jsonDir:String, fullSha:String):Array<BenchmarkResult> {
		final shaDir = Path.normalize(Path.join([jsonDir, fullSha]));
		if (!FileSystem.exists(shaDir) || !FileSystem.isDirectory(shaDir))
			throw 'why-benchkit: missing JSON folder for $fullSha: $shaDir';

		final docs:Array<BenchmarkResult> = [];
		function walk(absDir:String):Void {
			for (name in FileSystem.readDirectory(absDir)) {
				final child = Path.join([absDir, name]);
				if (FileSystem.isDirectory(child)) {
					walk(child);
					continue;
				}
				if (name == 'manifest.json' || !StringTools.endsWith(name, '.json'))
					continue;
				final cliTarget = Path.withoutExtension(name);
				docs.push(parseDoc(child, cliTarget));
			}
		}
		walk(shaDir);
		docs.sort((a, b) -> {
			final byVer = Reflect.compare(a.haxeVersion, b.haxeVersion);
			return byVer != 0 ? byVer : Reflect.compare(a.target, b.target);
		});
		return docs;
	}

	/**
		Compare CLI exit policy (pure):
		- `1` when zero paired measures
		- `1` when any major degradation
		- `1` when `failOnMissing` and any missing-side entry
		- otherwise `0`
	**/
	public static function exitCode(report:CompareReport, failOnMissing:Bool):Int {
		if (!Compare.hasPairedMeasures(report))
			return 1;
		if (Compare.degraded(report).length > 0)
			return 1;
		if (failOnMissing && Compare.missing(report).length > 0)
			return 1;
		return 0;
	}

	/** Human-readable compare table + summary counts (pure string). */
	public static function formatReport(report:CompareReport):String {
		final lines:Array<String> = [];
		lines.push('compare ${shortSha(report.base)}…${shortSha(report.head)} (threshold ${formatPct(report.threshold)})');
		lines.push('');
		lines.push(pad('SUITE', 18) + pad('MEASURE', 18) + pad('TARGET', 10) + pad('BASE', 12) + pad('HEAD', 12)
			+ pad('DELTA', 10) + 'VERDICT');
		lines.push(StringTools.lpad('', '-', 90));

		for (e in report.entries)
			lines.push(formatEntryRow(e));

		lines.push('');
		lines.push('paired=${Compare.pairedCount(report)}'
			+ ' improved=${Compare.improved(report).length}'
			+ ' degraded=${Compare.degraded(report).length}'
			+ ' unchanged=${Compare.unchanged(report).length}'
			+ ' missing=${Compare.missing(report).length}'
			+ ' (missing_base=${Compare.entriesWithVerdict(report, CompareVerdict.MissingBase).length}'
			+ ' missing_head=${Compare.entriesWithVerdict(report, CompareVerdict.MissingHead).length})');
		return lines.join('\n');
	}

	static function parseDoc(path:String, cliTarget:String):BenchmarkResult {
		final raw:Dynamic = try {
			Json.parse(File.getContent(path));
		} catch (e:Dynamic) {
			throw 'why-benchkit: failed to parse $path ($e)';
		};

		final haxeVersion = requiredString(raw, 'haxeVersion', path);
		final timestamp = requiredFloat(raw, 'timestamp', path);
		final commitHash = requiredString(raw, 'commitHash', path);
		final suitesRaw:Dynamic = Reflect.field(raw, 'results');
		if (suitesRaw == null || !Std.isOfType(suitesRaw, Array))
			throw 'why-benchkit: missing results array in $path';

		final suites:Array<SuiteResult> = [];
		for (suiteDyn in (suitesRaw : Array<Dynamic>)) {
			final suiteName = requiredString(suiteDyn, 'name', path);
			final measuresRaw:Dynamic = Reflect.field(suiteDyn, 'results');
			if (measuresRaw == null || !Std.isOfType(measuresRaw, Array))
				throw 'why-benchkit: missing suite results in $path';
			final measures:Array<MeasureResult> = [];
			for (mDyn in (measuresRaw : Array<Dynamic>)) {
				final mName = requiredString(mDyn, 'name', path);
				final durationMs = requiredFloat(mDyn, 'duration', path);
				final iterations = Std.int(requiredFloat(mDyn, 'iterations', path));
				final warmup = Std.int(requiredFloat(mDyn, 'warmup', path));
				final samplesField:Dynamic = Reflect.field(mDyn, 'samples');
				final measure:MeasureResult = if (samplesField != null && Std.isOfType(samplesField, Array)) {
					final samples:Array<Millisecond> = [
						for (s in (samplesField : Array<Dynamic>))
							new Millisecond(Std.parseFloat(Std.string(s)))
					];
					{
						name: mName,
						duration: new Millisecond(durationMs),
						iterations: iterations,
						warmup: warmup,
						samples: samples,
					};
				} else {
					{
						name: mName,
						duration: new Millisecond(durationMs),
						iterations: iterations,
						warmup: warmup,
					};
				};
				measures.push(measure);
			}
			suites.push({name: suiteName, results: measures});
		}

		// Identity for Compare uses CLI/filename target, not body `eval`.
		return {
			haxeVersion: haxeVersion,
			target: cliTarget,
			timestamp: timestamp,
			results: suites,
			commitHash: commitHash,
		};
	}

	static function requiredString(obj:Dynamic, field:String, path:String):String {
		final v:Dynamic = Reflect.field(obj, field);
		if (v == null)
			throw 'why-benchkit: missing $field in $path';
		final s = StringTools.trim(Std.string(v));
		if (s.length == 0)
			throw 'why-benchkit: empty $field in $path';
		return s;
	}

	static function requiredFloat(obj:Dynamic, field:String, path:String):Float {
		final v:Dynamic = Reflect.field(obj, field);
		if (v == null)
			throw 'why-benchkit: missing $field in $path';
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int))
			return (v : Float);
		final parsed = Std.parseFloat(Std.string(v));
		if (!Math.isFinite(parsed))
			throw 'why-benchkit: bad $field in $path';
		return parsed;
	}

	static function formatEntryRow(e:CompareEntry):String {
		return pad(e.suite, 18)
			+ pad(e.measure, 18)
			+ pad(e.target, 10)
			+ pad(formatOps(e.baseOps), 12)
			+ pad(formatOps(e.headOps), 12)
			+ pad(formatDelta(e.delta), 10)
			+ (e.verdict : String);
	}

	static function formatOps(ops:Null<Float>):String {
		if (ops == null)
			return '—';
		if (!Math.isFinite(ops))
			return 'inf';
		if (ops >= 1000)
			return Std.string(Math.round(ops));
		return fixed(ops, 1);
	}

	static function formatDelta(delta:Null<Float>):String {
		if (delta == null)
			return '—';
		if (!Math.isFinite(delta))
			return delta > 0 ? '+inf' : '-inf';
		final pct = delta * 100;
		final sign = pct > 0 ? '+' : '';
		return sign + fixed(pct, 1) + '%';
	}

	static function formatPct(threshold:Float):String {
		return fixed(threshold * 100, 0) + '%';
	}

	static function shortSha(sha:String):String {
		return sha.length > 7 ? sha.substr(0, 7) : sha;
	}

	static function fixed(v:Float, digits:Int):String {
		final factor = Math.pow(10, digits);
		final rounded = Math.round(v * factor) / factor;
		final s = Std.string(rounded);
		final dot = s.indexOf('.');
		if (digits <= 0)
			return dot < 0 ? s : s.substr(0, dot);
		if (dot < 0)
			return s + '.' + StringTools.lpad('', '0', digits);
		final frac = s.substr(dot + 1);
		if (frac.length >= digits)
			return s.substr(0, dot + 1 + digits);
		return s + StringTools.lpad('', '0', digits - frac.length);
	}

	static function pad(s:String, width:Int):String {
		if (s.length >= width)
			return s.substr(0, width - 1) + ' ';
		return s + StringTools.lpad('', ' ', width - s.length);
	}

	/**
		Fail when HostRun landed under `_dirty` or a folder other than `fullSha`.
		Must run while cwd is still the clean worktree — `HostGit.resolveOutput`
		probes git from the process cwd.
	**/
	static function assertCleanShaFolder(jsonDir:String, fullSha:String):Void {
		final resolved = HostGit.resolveOutput(jsonDir);
		if (resolved.dirty || resolved.folderId == '_dirty')
			throw 'why-benchkit: expected clean SHA folder for $fullSha, got _dirty (dirty worktree or unresolvable HEAD)';
		if (resolved.folderId != fullSha)
			throw 'why-benchkit: JSON folder mismatch: expected $fullSha, got ${resolved.folderId}';

		final expectedPath = Path.normalize(Path.join([jsonDir, fullSha]));
		if (!FileSystem.exists(expectedPath) || !FileSystem.isDirectory(expectedPath))
			throw 'why-benchkit: missing JSON output folder: $expectedPath';
	}

	/**
		Install worktree deps via `lix download`. Fail with an actionable message
		when `lix` is missing or exits non-zero.
		See README TODO: allow customizing the per-worktree install command.
	**/
	static function lixDownload(cwd:String):Void {
		Sys.println('why-benchkit: compare: lix download in $cwd');
		final result = runCommand('lix', ['download'], cwd);
		if (result.code == 0)
			return;

		final detail = result.stderr.length > 0 ? result.stderr : result.stdout;
		final hint = 'Install lix (https://github.com/lix-pm/lix.pm) and ensure it is on PATH, then retry.';
		if (result.missing)
			throw 'why-benchkit: `lix` not found while preparing worktree at $cwd. $hint';
		throw 'why-benchkit: `lix download` failed in $cwd (exit ${result.code})'
			+ (detail.length > 0 ? ': $detail' : '')
			+ '. $hint';
	}

	static function removeWorktree(repoRoot:String, worktreePath:String):Void {
		try {
			HostGit.gitOrFail(['worktree', 'remove', '--force', worktreePath], repoRoot);
		} catch (e:Dynamic) {
			Sys.println('why-benchkit: warning: failed to remove worktree $worktreePath ($e)');
			try {
				rmTree(worktreePath);
			} catch (ignore:Dynamic) {}
		}
	}

	static function absolutePath(path:String):String {
		final trimmed = StringTools.trim(path);
		if (trimmed.length == 0)
			return '';
		if (Path.isAbsolute(trimmed))
			return Path.normalize(trimmed);
		return Path.normalize(Path.join([Sys.getCwd(), trimmed]));
	}

	static function uniqueTempPath(prefix:String):String {
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
		return Path.normalize(Path.join([
			base,
			prefix + Std.string(Std.random(0x7fffffff)) + '-' + Std.string(Date.now().getTime()),
		]));
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

	/**
		Run a command with optional cwd. Uses `git`-style absolute argv when
		possible; for other tools, temporarily switches cwd.
	**/
	static function runCommand(cmd:String, args:Array<String>, cwd:String):CommandResult {
		final originalCwd = Sys.getCwd();
		try {
			Sys.setCwd(cwd);
			final process = new Process(cmd, args);
			final out = StringTools.trim(process.stdout.readAll().toString());
			final err = StringTools.trim(process.stderr.readAll().toString());
			final code = process.exitCode();
			process.close();
			Sys.setCwd(originalCwd);
			return {code: code, stdout: out, stderr: err, missing: false};
		} catch (e:Dynamic) {
			try {
				Sys.setCwd(originalCwd);
			} catch (ignore:Dynamic) {}
			final msg = Std.string(e);
			final missing = StringTools.startsWith(msg, 'Could not start process')
				|| msg.indexOf('No such file') >= 0
				|| msg.indexOf('not found') >= 0;
			return {code: 1, stdout: '', stderr: msg, missing: missing};
		}
	}
}

typedef HostCompareArtifacts = {
	final jsonDir:String;
	final baseSha:String;
	final headSha:String;
}

typedef CommandResult = {
	final code:Int;
	final stdout:String;
	final stderr:String;
	final missing:Bool;
}
