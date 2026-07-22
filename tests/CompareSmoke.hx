import why.benchkit.BenchmarkResult;
import why.benchkit.Compare;
import why.benchkit.CompareEntry;
import why.benchkit.CompareReport;
import why.benchkit.CompareVerdict;
import why.benchkit.MeasureResult;
import why.benchkit.SuiteResult;
import why.unit.time.Millisecond;

/**
	Pure Compare.diff smoke on interp (no travix / filesystem).
	Usage: haxe compare.hxml
**/
class CompareSmoke {
	static function main():Void {
		assertOpsPerSec();
		assertImproved();
		assertDegraded();
		assertUnchanged();
		assertMissingHead();
		assertMissingBase();
		assertZeroPaired();
		assertSummaryHelpers();
		assertDefaultThreshold();
		Sys.println("CompareSmoke ok");
	}

	static function assertOpsPerSec():Void {
		// 1000 iters in 1000 ms → 1000 ops/sec
		final ops = Compare.opsPerSec(1000, new Millisecond(1000));
		assertNear(ops, 1000.0, 1e-9, "opsPerSec 1000/1000ms");

		// 100 iters in 50 ms → 2000 ops/sec
		final ops2 = Compare.opsPerSec(100, new Millisecond(50));
		assertNear(ops2, 2000.0, 1e-9, "opsPerSec 100/50ms");
	}

	static function assertImproved():Void {
		// base: 1000 ops/sec; head: 1200 ops/sec → delta +0.20 >= 0.10
		final report = Compare.diff(
			[doc("4.3.0", "node", "S", [measure("m", 1000, 1000)])],
			[doc("4.3.0", "node", "S", [measure("m", 1200, 1000)])],
			{base: "aaa", head: "bbb", threshold: 0.10}
		);
		assertSingle(report, CompareVerdict.Improved, 0.20);
	}

	static function assertDegraded():Void {
		// base: 1000 ops/sec; head: 850 ops/sec → delta -0.15 <= -0.10
		final report = Compare.diff(
			[doc("4.3.0", "node", "S", [measure("m", 1000, 1000)])],
			[doc("4.3.0", "node", "S", [measure("m", 850, 1000)])],
			{base: "aaa", head: "bbb", threshold: 0.10}
		);
		assertSingle(report, CompareVerdict.Degraded, -0.15);
	}

	static function assertUnchanged():Void {
		// delta +0.05 < 0.10
		final report = Compare.diff(
			[doc("4.3.0", "node", "S", [measure("m", 1000, 1000)])],
			[doc("4.3.0", "node", "S", [measure("m", 1050, 1000)])],
			{base: "aaa", head: "bbb", threshold: 0.10}
		);
		assertSingle(report, CompareVerdict.Unchanged, 0.05);
	}

	static function assertMissingHead():Void {
		final report = Compare.diff(
			[doc("4.3.0", "node", "S", [measure("only_base", 1000, 1000)])],
			[doc("4.3.0", "node", "S", [])],
			{base: "aaa", head: "bbb"}
		);
		if (report.entries.length != 1)
			throw 'CompareSmoke: expected 1 entry, got ${report.entries.length}';
		final e = report.entries[0];
		if (e.verdict != CompareVerdict.MissingHead)
			throw 'CompareSmoke: expected missing_head, got ${e.verdict}';
		if (e.baseOps == null || e.headOps != null || e.delta != null)
			throw "CompareSmoke: missing_head should have baseOps only";
		if (Compare.hasPairedMeasures(report))
			throw "CompareSmoke: missing_head-only report should have zero paired";
	}

	static function assertMissingBase():Void {
		final report = Compare.diff(
			[doc("4.3.0", "node", "S", [])],
			[doc("4.3.0", "node", "S", [measure("only_head", 1000, 1000)])],
			{base: "aaa", head: "bbb"}
		);
		if (report.entries.length != 1)
			throw 'CompareSmoke: expected 1 entry, got ${report.entries.length}';
		final e = report.entries[0];
		if (e.verdict != CompareVerdict.MissingBase)
			throw 'CompareSmoke: expected missing_base, got ${e.verdict}';
		if (e.headOps == null || e.baseOps != null || e.delta != null)
			throw "CompareSmoke: missing_base should have headOps only";
		if (Compare.hasPairedMeasures(report))
			throw "CompareSmoke: missing_base-only report should have zero paired";
	}

	static function assertZeroPaired():Void {
		// Different haxe versions → keys do not pair
		final report = Compare.diff(
			[doc("4.2.0", "node", "S", [measure("m", 1000, 1000)])],
			[doc("4.3.0", "node", "S", [measure("m", 1000, 1000)])],
			{base: "aaa", head: "bbb"}
		);
		if (report.entries.length != 2)
			throw 'CompareSmoke: expected 2 unpaired entries, got ${report.entries.length}';
		if (Compare.pairedCount(report) != 0)
			throw 'CompareSmoke: expected pairedCount 0, got ${Compare.pairedCount(report)}';
		if (Compare.hasPairedMeasures(report))
			throw "CompareSmoke: cross-version report should fail hasPairedMeasures";
		if (Compare.missing(report).length != 2)
			throw "CompareSmoke: both sides should be missing counterparts";

		final empty = Compare.diff([], [], {base: "a", head: "b"});
		if (Compare.hasPairedMeasures(empty) || empty.entries.length != 0)
			throw "CompareSmoke: empty trees should be zero paired";
	}

	static function assertSummaryHelpers():Void {
		final report = Compare.diff(
			[
				doc("4.3.0", "node", "Suite", [
					measure("faster", 1000, 1000),
					measure("slower", 1000, 1000),
					measure("same", 1000, 1000),
					measure("gone", 1000, 1000),
				]),
			],
			[
				doc("4.3.0", "node", "Suite", [
					measure("faster", 1300, 1000), // +30%
					measure("slower", 800, 1000), // -20%
					measure("same", 1020, 1000), // +2%
					measure("new", 1000, 1000),
				]),
			],
			{base: "baseSha", head: "headSha", threshold: 0.10}
		);

		if (report.base != "baseSha" || report.head != "headSha")
			throw "CompareSmoke: report should echo base/head SHAs";
		if (report.threshold != 0.10)
			throw 'CompareSmoke: expected threshold 0.10, got ${report.threshold}';
		if (report.entries.length != 5)
			throw 'CompareSmoke: expected 5 entries, got ${report.entries.length}';
		if (Compare.improved(report).length != 1 || Compare.improved(report)[0].measure != "faster")
			throw "CompareSmoke: improved helper";
		if (Compare.degraded(report).length != 1 || Compare.degraded(report)[0].measure != "slower")
			throw "CompareSmoke: degraded helper";
		if (Compare.unchanged(report).length != 1 || Compare.unchanged(report)[0].measure != "same")
			throw "CompareSmoke: unchanged helper";
		if (Compare.missing(report).length != 2)
			throw "CompareSmoke: missing helper (gone + new)";
		if (Compare.pairedCount(report) != 3)
			throw 'CompareSmoke: expected 3 paired, got ${Compare.pairedCount(report)}';
		if (!Compare.hasPairedMeasures(report))
			throw "CompareSmoke: mixed report should have paired measures";

		// Sorted by key: haxeVersion, target, suite, measure
		final names = [for (e in report.entries) e.measure];
		final expected = ["faster", "gone", "new", "same", "slower"];
		if (names.join(",") != expected.join(","))
			throw 'CompareSmoke: expected sorted measures $expected, got $names';
	}

	static function assertDefaultThreshold():Void {
		// +9% is unchanged at default 0.10; +10% is improved
		final under = Compare.diff(
			[doc("4.3.0", "interp", "S", [measure("m", 1000, 1000)])],
			[doc("4.3.0", "interp", "S", [measure("m", 1090, 1000)])],
			{base: "a", head: "b"}
		);
		if (under.threshold != Compare.DEFAULT_THRESHOLD)
			throw 'CompareSmoke: default threshold should be ${Compare.DEFAULT_THRESHOLD}';
		if (under.entries[0].verdict != CompareVerdict.Unchanged)
			throw "CompareSmoke: +9% should be unchanged at default threshold";

		final at = Compare.diff(
			[doc("4.3.0", "interp", "S", [measure("m", 1000, 1000)])],
			[doc("4.3.0", "interp", "S", [measure("m", 1100, 1000)])],
			{base: "a", head: "b"}
		);
		if (at.entries[0].verdict != CompareVerdict.Improved)
			throw "CompareSmoke: +10% should be improved at default threshold";
	}

	static function assertSingle(report:CompareReport, verdict:CompareVerdict, expectedDelta:Float):Void {
		if (report.entries.length != 1)
			throw 'CompareSmoke: expected 1 entry for $verdict, got ${report.entries.length}';
		final e = report.entries[0];
		if (e.verdict != verdict)
			throw 'CompareSmoke: expected $verdict, got ${e.verdict}';
		if (e.delta == null)
			throw 'CompareSmoke: paired $verdict should have delta';
		assertNear(e.delta, expectedDelta, 1e-9, 'delta for $verdict');
		if (!Compare.hasPairedMeasures(report) || Compare.pairedCount(report) != 1)
			throw 'CompareSmoke: $verdict should count as paired';
		assertEntryIdentity(e, "4.3.0", "node", "S", "m");
	}

	static function assertEntryIdentity(
		e:CompareEntry,
		haxeVersion:String,
		target:String,
		suite:String,
		measure:String
	):Void {
		if (e.haxeVersion != haxeVersion || e.target != target || e.suite != suite || e.measure != measure)
			throw 'CompareSmoke: bad identity ${e.haxeVersion}/${e.target}/${e.suite}/${e.measure}';
	}

	static function assertNear(actual:Float, expected:Float, tol:Float, label:String):Void {
		if (!Math.isFinite(actual) || Math.abs(actual - expected) > tol)
			throw 'CompareSmoke: $label expected ~$expected, got $actual';
	}

	/** Build a measure with `iterations` timed runs lasting `durationMs` (mean). */
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
			commitHash: "testhash",
		};
	}
}
