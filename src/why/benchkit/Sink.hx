package why.benchkit;

/**
	Black-hole for benchmark return values so DCE / optimizers cannot erase the work.
**/
@:keep
class Sink {
	static var hole:Any = null;

	function new() {}

	/**
		Consume a value so the caller's work is observable to the runtime / DCE.
	**/
	public static function blackHole(value:Any):Void {
		hole = value;
		// Read-back keeps `hole` live across aggressive DCE; branch is never taken in practice.
		// (Avoid `hole != value` — NaN would throw because NaN != NaN.)
		if (hole == null && value != null)
			throw "why.benchkit.Sink: unreachable";
	}
}
