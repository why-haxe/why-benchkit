import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import why.benchkit.BenchmarkResult;
import why.benchkit.Compare;
import why.benchkit.CompareVerdict;
import why.benchkit.MeasureResult;
import why.benchkit.SuiteResult;
import why.benchkit.host.HostCompare;
import why.benchkit.host.HostPrComment;
import why.unit.time.Millisecond;

/**
	HostCompare load / format / exit-policy / PR-comment smoke (synthetic JSON, no travix).
	Usage: haxe hostcomparecmd.hxml
**/
class HostCompareCommandSmoke {
	static function main():Void {
		assertLoadRewritesTargetFromFilename();
		assertExitPolicy();
		assertFormatReport();
		assertMarkdownAndPrHelpers();
		Sys.println('HostCompareCommandSmoke ok');
	}

	/** Body `target` is often `eval` for interp; identity must use filename. */
	static function assertLoadRewritesTargetFromFilename():Void {
		final root = uniqueTempDir('why-benchkit-compare-cmd-');
		try {
			final sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
			final haxeVer = '4.3.7';
			final dir = Path.join([root, sha, haxeVer]);
			ensureDir(dir);
			final path = Path.join([dir, 'interp.json']);
			File.saveContent(path, Json.stringify({
				haxeVersion: haxeVer,
				target: 'eval',
				timestamp: 1.0,
				commitHash: sha,
				results: [
					{
						name: 'suite_a',
						results: [
							{
								name: 'm1',
								duration: 100.0,
								iterations: 1000,
								warmup: 0,
								samples: [100.0],
							},
						],
					},
				],
			}, '  '));

			final docs = HostCompare.loadDocs(root, sha);
			if (docs.length != 1)
				throw 'HostCompareCommandSmoke: expected 1 doc, got ${docs.length}';
			if (docs[0].target != 'interp')
				throw 'HostCompareCommandSmoke: expected target interp from filename, got ${docs[0].target}';
			if (docs[0].haxeVersion != haxeVer)
				throw 'HostCompareCommandSmoke: bad haxeVersion';
			if (docs[0].results[0].results[0].iterations != 1000)
				throw 'HostCompareCommandSmoke: bad iterations';

			final paired = Compare.diff(docs, docs, {base: sha, head: sha, threshold: 0.10});
			if (!Compare.hasPairedMeasures(paired))
				throw 'HostCompareCommandSmoke: expected paired after rewrite';
			if (paired.entries[0].target != 'interp')
				throw 'HostCompareCommandSmoke: Compare key target should be interp';
			if (paired.entries[0].verdict != CompareVerdict.Unchanged)
				throw 'HostCompareCommandSmoke: expected unchanged self-diff';

			Sys.println('HostCompareCommandSmoke loadDocs target rewrite ok');
		} catch (e:Dynamic) {
			rmTree(root);
			throw e;
		}
		rmTree(root);
	}

	static function assertExitPolicy():Void {
		final baseDoc = doc('4.3.0', 'node', 'S', [
			measure('fast', 1000, 1000),
			measure('only_base', 1000, 1000),
		]);
		final headFaster = doc('4.3.0', 'node', 'S', [measure('fast', 1000, 800)]);
		final headSlower = doc('4.3.0', 'node', 'S', [measure('fast', 1000, 1200)]);

		final improved = Compare.diff([baseDoc], [headFaster], {base: 'a', head: 'b', threshold: 0.10});
		if (HostCompare.exitCode(improved, false) != 0)
			throw 'HostCompareCommandSmoke: improved+missing should exit 0 without --fail-on-missing';
		if (HostCompare.exitCode(improved, true) != 1)
			throw 'HostCompareCommandSmoke: missing side should exit 1 with --fail-on-missing';

		final degraded = Compare.diff([baseDoc], [headSlower], {base: 'a', head: 'b', threshold: 0.10});
		if (HostCompare.exitCode(degraded, false) != 1)
			throw 'HostCompareCommandSmoke: degraded should exit 1';

		final zeroPaired = Compare.diff(
			[doc('4.3.0', 'node', 'S', [measure('a', 1, 1)])],
			[doc('4.3.1', 'node', 'S', [measure('a', 1, 1)])],
			{base: 'a', head: 'b'}
		);
		if (Compare.hasPairedMeasures(zeroPaired))
			throw 'HostCompareCommandSmoke: expected zero paired across haxeVersion mismatch';
		if (HostCompare.exitCode(zeroPaired, false) != 1)
			throw 'HostCompareCommandSmoke: zero paired must exit 1';

		Sys.println('HostCompareCommandSmoke exit policy ok');
	}

	static function assertFormatReport():Void {
		final report = Compare.diff(
			[doc('4.3.0', 'interp', 'suite', [measure('m', 1000, 1000)])],
			[doc('4.3.0', 'interp', 'suite', [measure('m', 1000, 1000)])],
			{base: 'aaaaaaaa', head: 'bbbbbbbb', threshold: 0.10}
		);
		final text = HostCompare.formatReport(report);
		if (text.indexOf('SUITE') < 0 || text.indexOf('VERDICT') < 0)
			throw 'HostCompareCommandSmoke: format missing header';
		if (text.indexOf('unchanged') < 0)
			throw 'HostCompareCommandSmoke: format missing verdict';
		if (text.indexOf('paired=1') < 0 || text.indexOf('missing=0') < 0)
			throw 'HostCompareCommandSmoke: format missing summary counts';
		Sys.println('HostCompareCommandSmoke formatReport ok');
	}

	/** Markdown + pure PR helpers (no network / gh). */
	static function assertMarkdownAndPrHelpers():Void {
		final baseDoc = doc('4.3.0', 'node', 'S', [
			measure('slow', 1000, 1000),
			measure('fast', 1000, 1000),
			measure('only_base', 1000, 1000),
		]);
		final headDoc = doc('4.3.0', 'node', 'S', [
			measure('slow', 1000, 1300), // degraded
			measure('fast', 1000, 700), // improved
		]);
		final report = Compare.diff([baseDoc], [headDoc], {
			base: 'aaaaaaaaaaaaaaaa',
			head: 'bbbbbbbbbbbbbbbb',
			threshold: 0.10,
		});
		final md = HostCompare.formatMarkdownReport(report);
		if (md.indexOf(HostPrComment.MARKER) < 0)
			throw 'HostCompareCommandSmoke: markdown missing marker';
		final degIdx = md.indexOf('### Degraded');
		final impIdx = md.indexOf('### Improved');
		final uncIdx = md.indexOf('### Unchanged');
		final missIdx = md.indexOf('### Missing');
		if (degIdx < 0 || impIdx < 0 || uncIdx < 0 || missIdx < 0)
			throw 'HostCompareCommandSmoke: markdown missing sections';
		if (!(degIdx < impIdx && impIdx < uncIdx && uncIdx < missIdx))
			throw 'HostCompareCommandSmoke: markdown section order should be degraded→improved→unchanged→missing';
		if (md.indexOf('degraded') < 0 || md.indexOf('improved') < 0)
			throw 'HostCompareCommandSmoke: markdown missing verdicts';
		if (md.indexOf('paired=2') < 0)
			throw 'HostCompareCommandSmoke: markdown missing summary';

		if (HostPrComment.prNumberFromEvent({pull_request: {number: 42}}) != 42)
			throw 'HostCompareCommandSmoke: prNumberFromEvent failed';
		if (HostPrComment.prNumberFromEvent({issue: {number: 1}}) != null)
			throw 'HostCompareCommandSmoke: prNumberFromEvent should ignore non-PR events';
		if (HostPrComment.prNumberFromRef('refs/pull/99/merge') != 99)
			throw 'HostCompareCommandSmoke: prNumberFromRef failed';
		if (HostPrComment.prNumberFromRef('refs/heads/main') != null)
			throw 'HostCompareCommandSmoke: prNumberFromRef should ignore branches';

		final repo = HostPrComment.parseRepo('acme/why-benchkit');
		if (repo == null || repo.owner != 'acme' || repo.repo != 'why-benchkit')
			throw 'HostCompareCommandSmoke: parseRepo failed';
		if (HostPrComment.parseRepo('bad') != null)
			throw 'HostCompareCommandSmoke: parseRepo should reject bad input';

		final id = HostPrComment.findCommentId([
			{id: 1, body: 'hello'},
			{id: 2, body: 'x ' + HostPrComment.MARKER + ' y'},
			{id: 3, body: HostPrComment.MARKER},
		], HostPrComment.MARKER);
		if (id != 2)
			throw 'HostCompareCommandSmoke: findCommentId should return first match (got $id)';
		if (HostPrComment.findCommentId([{id: 9, body: 'nope'}], HostPrComment.MARKER) != null)
			throw 'HostCompareCommandSmoke: findCommentId should miss';

		// Do not call maybePost/postOrUpdate here — may hit a real PR via `gh`.
		Sys.println('HostCompareCommandSmoke markdown + PR helpers ok');
	}

	static function measure(name:String, iterations:Int, durationMs:Float):MeasureResult {
		return {
			name: name,
			duration: new Millisecond(durationMs),
			iterations: iterations,
			warmup: 0,
		};
	}

	static function doc(
		haxeVersion:String,
		target:String,
		suiteName:String,
		measures:Array<MeasureResult>
	):BenchmarkResult {
		final suite:SuiteResult = {name: suiteName, results: measures};
		return {
			haxeVersion: haxeVersion,
			target: target,
			timestamp: 0,
			results: [suite],
			commitHash: 'testhash',
		};
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

	static function ensureDir(path:String):Void {
		final normalized = Path.normalize(path);
		if (FileSystem.exists(normalized)) {
			if (!FileSystem.isDirectory(normalized))
				throw 'HostCompareCommandSmoke: not a directory: $normalized';
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
