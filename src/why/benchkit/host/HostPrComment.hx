package why.benchkit.host;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import why.benchkit.CompareReport;

/**
	Optional GitHub PR comment for compare reports.

	Prefer the `gh` CLI when available; otherwise use Actions env
	(`GITHUB_EVENT_PATH` / `GITHUB_TOKEN` / `GITHUB_REPOSITORY`) + `curl`.

	Failures are returned as `Failed` / printed as warnings — callers must not
	let comment errors override compare exit codes (warn-only).
**/
class HostPrComment {
	/** HTML comment marker for idempotent create-or-update. */
	public static inline final MARKER:String = '<!-- why-benchkit-compare -->';

	function new() {}

	/**
		Warn-only entry used by the CLI: never throws; prints skip / success /
		warning lines. Does not change process exit codes.
	**/
	public static function maybePost(report:CompareReport):Void {
		try {
			switch postOrUpdate(report) {
				case Skipped(reason):
					Sys.println('why-benchkit: --post-pr-comment: $reason; skipping');
				case Posted(url):
					Sys.println('why-benchkit: --post-pr-comment: posted $url');
				case Updated(url):
					Sys.println('why-benchkit: --post-pr-comment: updated $url');
				case Failed(message):
					Sys.println('why-benchkit: warning: failed to post PR comment: $message');
			}
		} catch (e:Dynamic) {
			Sys.println('why-benchkit: warning: failed to post PR comment: $e');
		}
	}

	/**
		Detect PR context and create or update a single bot comment whose body
		contains `MARKER`. Pure detection helpers are public for smoke tests.
	**/
	public static function postOrUpdate(report:CompareReport):PrCommentResult {
		final body = HostCompare.formatMarkdownReport(report);
		final ctx = resolveContext();
		if (ctx == null)
			return Skipped('not in a pull request context (or missing credentials)');

		return switch ctx.transport {
			case Gh:
				postViaGh(ctx, body);
			case Curl(token, apiUrl):
				postViaCurl(ctx, body, token, apiUrl);
		};
	}

	/** PR number from a GitHub Actions event payload (`pull_request.number`). */
	public static function prNumberFromEvent(event:Dynamic):Null<Int> {
		if (event == null)
			return null;
		final pr:Dynamic = Reflect.field(event, 'pull_request');
		if (pr == null)
			return null;
		final n:Dynamic = Reflect.field(pr, 'number');
		return positiveInt(n);
	}

	/** PR number from `GITHUB_REF` like `refs/pull/123/merge`. */
	public static function prNumberFromRef(ref:String):Null<Int> {
		final trimmed = StringTools.trim(ref);
		if (!StringTools.startsWith(trimmed, 'refs/pull/'))
			return null;
		final rest = trimmed.substr('refs/pull/'.length);
		final slash = rest.indexOf('/');
		final numStr = slash < 0 ? rest : rest.substr(0, slash);
		return positiveInt(Std.parseInt(numStr));
	}

	/** Parse `owner/repo` from `GITHUB_REPOSITORY`. */
	public static function parseRepo(nameWithOwner:String):Null<{owner:String, repo:String}> {
		final trimmed = StringTools.trim(nameWithOwner);
		final slash = trimmed.indexOf('/');
		if (slash <= 0 || slash >= trimmed.length - 1)
			return null;
		final owner = trimmed.substr(0, slash);
		final repo = trimmed.substr(slash + 1);
		if (owner.length == 0 || repo.length == 0 || repo.indexOf('/') >= 0)
			return null;
		return {owner: owner, repo: repo};
	}

	/**
		Return the first issue-comment id whose `body` contains `marker`,
		or `null` when none match.
	**/
	public static function findCommentId(comments:Array<Dynamic>, marker:String):Null<Int> {
		for (c in comments) {
			final body:Dynamic = Reflect.field(c, 'body');
			if (body == null)
				continue;
			if (Std.string(body).indexOf(marker) < 0)
				continue;
			final id = positiveInt(Reflect.field(c, 'id'));
			if (id != null)
				return id;
		}
		return null;
	}

	static function resolveContext():Null<PrCommentContext> {
		final fromGh = resolveViaGh();
		if (fromGh != null)
			return fromGh;
		return resolveViaActionsEnv();
	}

	static function resolveViaGh():Null<PrCommentContext> {
		final prView = runCapture('gh', ['pr', 'view', '--json', 'number']);
		if (prView.missing || prView.code != 0)
			return null;
		final parsed:Dynamic = try Json.parse(prView.stdout) catch (e:Dynamic) null;
		final number = positiveInt(parsed == null ? null : Reflect.field(parsed, 'number'));
		if (number == null)
			return null;

		final repoView = runCapture('gh', ['repo', 'view', '--json', 'nameWithOwner']);
		if (repoView.code != 0)
			return null;
		final repoParsed:Dynamic = try Json.parse(repoView.stdout) catch (e:Dynamic) null;
		final nameWithOwner = repoParsed == null ? null : Reflect.field(repoParsed, 'nameWithOwner');
		final repo = nameWithOwner == null ? null : parseRepo(Std.string(nameWithOwner));
		if (repo == null)
			return null;

		return {
			owner: repo.owner,
			repo: repo.repo,
			number: number,
			transport: Gh,
		};
	}

	static function resolveViaActionsEnv():Null<PrCommentContext> {
		final token = nonEmptyEnv('GITHUB_TOKEN');
		if (token == null)
			return null;

		final repoParts = switch nonEmptyEnv('GITHUB_REPOSITORY') {
			case null:
				null;
			case s:
				parseRepo(s);
		};
		if (repoParts == null)
			return null;

		final number = switch nonEmptyEnv('GITHUB_EVENT_PATH') {
			case null:
				switch nonEmptyEnv('GITHUB_REF') {
					case null:
						null;
					case ref:
						prNumberFromRef(ref);
				};
			case eventPath:
				final fromEvent = readPrNumberFromEventPath(eventPath);
				fromEvent != null ? fromEvent : switch nonEmptyEnv('GITHUB_REF') {
					case null:
						null;
					case ref:
						prNumberFromRef(ref);
				};
		};
		if (number == null)
			return null;

		final apiRaw = switch nonEmptyEnv('GITHUB_API_URL') {
			case null:
				'https://api.github.com';
			case u:
				u;
		};
		final api = StringTools.endsWith(apiRaw, '/') ? apiRaw.substr(0, apiRaw.length - 1) : apiRaw;

		return {
			owner: repoParts.owner,
			repo: repoParts.repo,
			number: number,
			transport: Curl(token, api),
		};
	}

	static function readPrNumberFromEventPath(path:String):Null<Int> {
		if (!FileSystem.exists(path))
			return null;
		try {
			final event:Dynamic = Json.parse(File.getContent(path));
			return prNumberFromEvent(event);
		} catch (e:Dynamic) {
			return null;
		}
	}

	static function postViaGh(ctx:PrCommentContext, body:String):PrCommentResult {
		final list = runCapture('gh', [
			'api',
			'repos/${ctx.owner}/${ctx.repo}/issues/${ctx.number}/comments',
			'--paginate',
		]);
		if (list.code != 0) {
			final detail = list.stderr.length > 0 ? list.stderr : list.stdout;
			return Failed('gh api list comments failed (exit ${list.code})${detail.length > 0 ? ": " + detail : ""}');
		}

		final comments = parseCommentArray(list.stdout);
		final existingId = findCommentId(comments, MARKER);
		final payloadPath = writeJsonTemp({body: body});
		try {
			final result = if (existingId != null) {
				final patched = runCapture('gh', [
					'api',
					'--method',
					'PATCH',
					'repos/${ctx.owner}/${ctx.repo}/issues/comments/$existingId',
					'--input',
					payloadPath,
				]);
				mapMutationResult(patched, true);
			} else {
				final created = runCapture('gh', [
					'api',
					'--method',
					'POST',
					'repos/${ctx.owner}/${ctx.repo}/issues/${ctx.number}/comments',
					'--input',
					payloadPath,
				]);
				mapMutationResult(created, false);
			};
			deleteQuiet(payloadPath);
			return result;
		} catch (e:Dynamic) {
			deleteQuiet(payloadPath);
			return Failed(Std.string(e));
		}
	}

	static function postViaCurl(
		ctx:PrCommentContext,
		body:String,
		token:String,
		apiUrl:String
	):PrCommentResult {
		final listUrl = '$apiUrl/repos/${ctx.owner}/${ctx.repo}/issues/${ctx.number}/comments';
		final collected:Array<Dynamic> = [];
		var page = 1;
		// Page with per_page=100 so idempotent update still finds MARKER on busy PRs.
		while (page <= 50) {
			final listed = curlJson('GET', '$listUrl?per_page=100&page=$page', token, null);
			if (listed.code != 0) {
				final detail = listed.stderr.length > 0 ? listed.stderr : listed.stdout;
				return Failed('curl list comments failed (exit ${listed.code})'
					+ (detail.length > 0 ? ': $detail' : ''));
			}
			final batch = parseCommentArray(listed.stdout);
			if (batch.length == 0)
				break;
			for (c in batch)
				collected.push(c);
			if (batch.length < 100)
				break;
			page++;
		}

		final existingId = findCommentId(collected, MARKER);
		final payloadPath = writeJsonTemp({body: body});
		try {
			final result = if (existingId != null) {
				final url = '$apiUrl/repos/${ctx.owner}/${ctx.repo}/issues/comments/$existingId';
				mapMutationResult(curlJson('PATCH', url, token, payloadPath), true);
			} else {
				mapMutationResult(curlJson('POST', listUrl, token, payloadPath), false);
			};
			deleteQuiet(payloadPath);
			return result;
		} catch (e:Dynamic) {
			deleteQuiet(payloadPath);
			return Failed(Std.string(e));
		}
	}

	static function deleteQuiet(path:String):Void {
		try {
			FileSystem.deleteFile(path);
		} catch (ignore:Dynamic) {}
	}

	static function mapMutationResult(res:CommandCapture, updated:Bool):PrCommentResult {
		if (res.code != 0) {
			final detail = res.stderr.length > 0 ? res.stderr : res.stdout;
			return Failed('GitHub comment ${updated ? "update" : "create"} failed (exit ${res.code})'
				+ (detail.length > 0 ? ': $detail' : ''));
		}
		final parsed:Dynamic = try Json.parse(res.stdout) catch (e:Dynamic) null;
		final url = parsed == null ? null : Reflect.field(parsed, 'html_url');
		final link = url == null ? '(no url)' : Std.string(url);
		return updated ? Updated(link) : Posted(link);
	}

	static function parseCommentArray(raw:String):Array<Dynamic> {
		final trimmed = StringTools.trim(raw);
		if (trimmed.length == 0)
			return [];
		// `--paginate` may concatenate JSON arrays; accept a single array or NDJSON-ish concat.
		try {
			final parsed:Dynamic = Json.parse(trimmed);
			if (Std.isOfType(parsed, Array))
				return (parsed : Array<Dynamic>);
		} catch (e:Dynamic) {}

		// gh --paginate sometimes yields `][`; merge into one array.
		final merged = StringTools.replace(trimmed, '][', ',');
		try {
			final parsed:Dynamic = Json.parse(merged);
			if (Std.isOfType(parsed, Array))
				return (parsed : Array<Dynamic>);
		} catch (e:Dynamic) {}

		throw 'could not parse comments JSON';
	}

	static function writeJsonTemp(payload:Dynamic):String {
		final path = uniqueTempFile('why-benchkit-pr-comment-');
		File.saveContent(path, Json.stringify(payload));
		return path;
	}

	static function curlJson(
		method:String,
		url:String,
		token:String,
		bodyPath:Null<String>
	):CommandCapture {
		// `-f` / `--fail`: HTTP >= 400 → non-zero exit (otherwise curl exits 0
		// and callers could treat an error JSON body as a successful post).
		final args = [
			'-sS',
			'-f',
			'-X',
			method,
			'-H',
			'Authorization: Bearer $token',
			'-H',
			'Accept: application/vnd.github+json',
			'-H',
			'X-GitHub-Api-Version: 2022-11-28',
		];
		if (bodyPath != null) {
			args.push('-H');
			args.push('Content-Type: application/json');
			args.push('--data-binary');
			args.push('@$bodyPath');
		}
		args.push(url);
		return runCapture('curl', args);
	}

	static function runCapture(cmd:String, args:Array<String>):CommandCapture {
		try {
			final process = new Process(cmd, args);
			final out = StringTools.trim(process.stdout.readAll().toString());
			final err = StringTools.trim(process.stderr.readAll().toString());
			final code = process.exitCode();
			process.close();
			return {code: code, stdout: out, stderr: err, missing: false};
		} catch (e:Dynamic) {
			final msg = Std.string(e);
			final missing = StringTools.startsWith(msg, 'Could not start process')
				|| msg.indexOf('No such file') >= 0
				|| msg.indexOf('not found') >= 0;
			return {code: 1, stdout: '', stderr: msg, missing: missing};
		}
	}

	static function uniqueTempFile(prefix:String):String {
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
			prefix + Std.string(Std.random(0x7fffffff)) + '-' + Std.string(Date.now().getTime()) + '.json',
		]));
	}

	static function nonEmptyEnv(name:String):Null<String> {
		return switch Sys.getEnv(name) {
			case null | '':
				null;
			case s:
				final trimmed = StringTools.trim(s);
				trimmed.length == 0 ? null : trimmed;
		};
	}

	static function positiveInt(v:Dynamic):Null<Int> {
		if (v == null)
			return null;
		final n = if (Std.isOfType(v, Int))
			(v : Int)
		else if (Std.isOfType(v, Float))
			Std.int((v : Float))
		else
			Std.parseInt(Std.string(v));
		if (n == null || n <= 0)
			return null;
		return n;
	}
}

enum PrCommentResult {
	Skipped(reason:String);
	Posted(url:String);
	Updated(url:String);
	Failed(message:String);
}

enum PrCommentTransport {
	Gh;
	Curl(token:String, apiUrl:String);
}

typedef PrCommentContext = {
	final owner:String;
	final repo:String;
	final number:Int;
	final transport:PrCommentTransport;
}

typedef CommandCapture = {
	final code:Int;
	final stdout:String;
	final stderr:String;
	final missing:Bool;
}
