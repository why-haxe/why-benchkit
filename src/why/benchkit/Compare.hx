package why.benchkit;

import why.unit.time.Millisecond;
import why.unit.time.Second;

/**
	Side-effect-free align / diff / classify for two benchmark result sets.

	Identity key: `(haxeVersion, target, suite, measure)`.
	Callers should set `BenchmarkResult.target` to the CLI/host target used in
	the JSON path (filename / config), not necessarily the runtime target string.

	Metric: `opsPerSec = iterations / (durationMs / 1000)` from mean `duration`.
	Relative delta: `(headOps - baseOps) / baseOps`. Higher ops/sec is better.

	v1: mean ± threshold only (no sample variance). Host owns I/O and exit codes;
	use `hasPairedMeasures` — zero paired measures should fail the compare CLI.
**/
class Compare {
	/** Default major-change threshold (≥ 10% relative ops/sec). */
	public static inline final DEFAULT_THRESHOLD:Float = 0.10;

	function new() {}

	/** Ops/sec from timed iterations and mean duration (ms). */
	public static function opsPerSec(iterations:Int, duration:Millisecond):Float {
		final seconds:Float = (duration : Second).toFloat();
		if (seconds <= 0)
			return Math.POSITIVE_INFINITY;
		return iterations / seconds;
	}

	/**
		Align measures from `baseDocs` and `headDocs`, classify each pair.
		Pure: no filesystem / git / process I/O.
	**/
	public static function diff(
		baseDocs:Array<BenchmarkResult>,
		headDocs:Array<BenchmarkResult>,
		options:CompareOptions
	):CompareReport {
		final threshold = options.threshold ?? DEFAULT_THRESHOLD;
		final baseMap = indexMeasures(baseDocs);
		final headMap = indexMeasures(headDocs);
		final keys = unionSortedKeys(baseMap, headMap);
		final entries = [
			for (key in keys)
				classify(parseKey(key), baseMap.get(key), headMap.get(key), threshold)
		];
		return {
			base: options.base,
			head: options.head,
			threshold: threshold,
			entries: entries,
		};
	}

	/** Entries with the given verdict (summary helper for reporters / CLI). */
	public static function entriesWithVerdict(report:CompareReport, verdict:CompareVerdict):Array<CompareEntry> {
		return report.entries.filter(e -> e.verdict == verdict);
	}

	public static function degraded(report:CompareReport):Array<CompareEntry> {
		return entriesWithVerdict(report, CompareVerdict.Degraded);
	}

	public static function improved(report:CompareReport):Array<CompareEntry> {
		return entriesWithVerdict(report, CompareVerdict.Improved);
	}

	public static function unchanged(report:CompareReport):Array<CompareEntry> {
		return entriesWithVerdict(report, CompareVerdict.Unchanged);
	}

	/** Missing on either side (`missing_base` or `missing_head`). */
	public static function missing(report:CompareReport):Array<CompareEntry> {
		return report.entries.filter(e ->
			e.verdict == CompareVerdict.MissingBase || e.verdict == CompareVerdict.MissingHead
		);
	}

	/** Count of measures present on both base and head (not a missing-* verdict). */
	public static function pairedCount(report:CompareReport):Int {
		return report.entries.filter(e ->
			e.verdict != CompareVerdict.MissingBase && e.verdict != CompareVerdict.MissingHead
		).length;
	}

	/**
		True when at least one measure aligns on both sides.
		Host compare should exit non-zero when this is false (haxeVersion /
		rename miss, empty trees, etc.).
	**/
	public static function hasPairedMeasures(report:CompareReport):Bool {
		return pairedCount(report) > 0;
	}

	static function indexMeasures(docs:Array<BenchmarkResult>):Map<String, Float> {
		final map = new Map<String, Float>();
		for (doc in docs) {
			for (suite in doc.results) {
				for (m in suite.results) {
					final key = encodeKey(doc.haxeVersion, doc.target, suite.name, m.name);
					map.set(key, opsPerSec(m.iterations, m.duration));
				}
			}
		}
		return map;
	}

	static function unionSortedKeys(a:Map<String, Float>, b:Map<String, Float>):Array<String> {
		final seen = new Map<String, Bool>();
		final keys:Array<String> = [];
		for (k in a.keys()) {
			seen.set(k, true);
			keys.push(k);
		}
		for (k in b.keys()) {
			if (!seen.exists(k))
				keys.push(k);
		}
		keys.sort(Reflect.compare);
		return keys;
	}

	static function classify(
		parts:{
			haxeVersion:String,
			target:String,
			suite:String,
			measure:String
		},
		baseOps:Null<Float>,
		headOps:Null<Float>,
		threshold:Float
	):CompareEntry {
		if (baseOps == null) {
			return {
				haxeVersion: parts.haxeVersion,
				target: parts.target,
				suite: parts.suite,
				measure: parts.measure,
				headOps: headOps,
				verdict: CompareVerdict.MissingBase,
			};
		}
		if (headOps == null) {
			return {
				haxeVersion: parts.haxeVersion,
				target: parts.target,
				suite: parts.suite,
				measure: parts.measure,
				baseOps: baseOps,
				verdict: CompareVerdict.MissingHead,
			};
		}

		final delta = relativeDelta(baseOps, headOps);
		final verdict = if (delta >= threshold)
			CompareVerdict.Improved
		else if (delta <= -threshold)
			CompareVerdict.Degraded
		else
			CompareVerdict.Unchanged;

		return {
			haxeVersion: parts.haxeVersion,
			target: parts.target,
			suite: parts.suite,
			measure: parts.measure,
			baseOps: baseOps,
			headOps: headOps,
			delta: delta,
			verdict: verdict,
		};
	}

	/** `(head - base) / base`; both zero → 0; base zero and head > 0 → +∞. */
	static function relativeDelta(baseOps:Float, headOps:Float):Float {
		if (baseOps == 0)
			return headOps == 0 ? 0.0 : Math.POSITIVE_INFINITY;
		return (headOps - baseOps) / baseOps;
	}

	static inline function encodeKey(haxeVersion:String, target:String, suite:String, measure:String):String {
		// Unit separator — unlikely in version/target/suite/measure names.
		return haxeVersion + "\x1f" + target + "\x1f" + suite + "\x1f" + measure;
	}

	static function parseKey(key:String):{
		haxeVersion:String,
		target:String,
		suite:String,
		measure:String
	} {
		final parts = key.split("\x1f");
		if (parts.length != 4)
			throw 'why.benchkit.Compare: corrupt measure key $key';
		return {
			haxeVersion: parts[0],
			target: parts[1],
			suite: parts[2],
			measure: parts[3],
		};
	}
}
