package why.benchkit.host;

import haxe.io.Path;
import why.benchkit.Compare;
import why.benchkit.CompareReport;

/**
	`why-benchkit compare` subcommand: run the suite at two SHAs into an OS-temp
	`json-dir`, diff mean ops/sec, print a table, and exit per compare policy.
**/
@:alias(false)
class HostCompareCommand {
	@:flag(false)
	final libraryRoot:String;

	/**
		Baseline commit (required). Full or unambiguous short SHA / ref.
	**/
	@:alias(false)
	@:optional
	public var base:String;

	/**
		Candidate commit (required). Full or unambiguous short SHA / ref.
	**/
	@:alias(false)
	@:optional
	public var head:String;

	/**
		Comma-separated targets (required). Known: interp,neko,python,node,js,lua,cpp,jvm
	**/
	@:alias(false)
	@:optional
	public var targets:Targets;

	/**
		Independent timed loops per measure after warmup (default 5). Must be >= 1.
	**/
	@:alias(false)
	public var samples:Int = 5;

	/**
		Relative ops/sec delta for major change (default 0.10 = 10%)
	**/
	@:alias(false)
	public var threshold:Float = Compare.DEFAULT_THRESHOLD;

	/**
		Non-zero exit when any measure exists on only one side
	**/
	@:flag('fail-on-missing')
	@:alias(false)
	public var failOnMissing:Bool = false;

	/**
		Post (or update) a compare markdown summary on the current GitHub PR.
		Off by default. Comment failure warns only — never overrides compare exit codes.
	**/
	@:flag('post-pr-comment')
	@:alias(false)
	public var postPrComment:Bool = false;

	public function new(libraryRoot:String) {
		this.libraryRoot = libraryRoot;
	}

	/**
		Run the consumer suite at `--base` then `--head` (OS-temp worktrees +
		`lix download`), load JSON, print a compare table, and exit:
		`0` when there is at least one paired measure and no major degradations
		(and no missing sides if `--fail-on-missing`); `1` on degradation,
		zero paired measures, orchestration/load failure, or fail-on-missing hits.
		Creates its own OS-temp `json-dir` (no `--json-dir` flag).
		With `--post-pr-comment`, also posts/updates a PR comment (warn-only on failure).
	**/
	@:defaultCommand
	public function run():Void {
		try {
			final baseRef = requiredString(base, '--base');
			final headRef = requiredString(head, '--head');
			if (targets == null || targets.length == 0) {
				Sys.println('why-benchkit: --targets is required');
				Sys.println('Known targets: ${Targets.ALL.join(",")}');
				Sys.exit(1);
				return;
			}
			if (samples < 1) {
				Sys.println('why-benchkit: --samples must be >= 1');
				Sys.exit(1);
				return;
			}
			if (!Math.isFinite(threshold) || threshold < 0) {
				Sys.println('why-benchkit: --threshold must be a non-negative finite number');
				Sys.exit(1);
				return;
			}

			final libRoot = Path.normalize(absolutePath(libraryRoot));
			final outcome = HostCompare.withRuns(baseRef, headRef, targets, libRoot, samples, artifacts -> {
				final baseDocs = HostCompare.loadDocs(artifacts.jsonDir, artifacts.baseSha);
				final headDocs = HostCompare.loadDocs(artifacts.jsonDir, artifacts.headSha);
				final report:CompareReport = Compare.diff(baseDocs, headDocs, {
					base: artifacts.baseSha,
					head: artifacts.headSha,
					threshold: threshold,
				});
				Sys.println(HostCompare.formatReport(report));
				return {
					code: HostCompare.exitCode(report, failOnMissing),
					report: report,
				};
			});
			// Flag-gated; skipped entirely when off (no gh / network). Warn-only on failure.
			if (postPrComment)
				HostPrComment.maybePost(outcome.report);
			Sys.exit(outcome.code);
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
		Sys.println(tink.Cli.getDoc(this, new tink.cli.doc.DefaultFormatter('why-benchkit compare')));
	}

	static function requiredString(value:Null<String>, flag:String):String {
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
		return raw;
	}

	static function absolutePath(path:String):String {
		if (Path.isAbsolute(path))
			return path;
		return Path.join([Sys.getCwd(), path]);
	}
}
