package why.benchkit.host;

/**
	Parsed options for `why-benchkit run`.
**/
class HostOptions {
	/** Targets to run (travix names). */
	public final targets:Array<String>;

	/** Directory for per-target JSON (`<dir>/<target>.json`); `null` if omitted. */
	public final jsonDir:Null<String>;

	public function new(targets:Array<String>, jsonDir:Null<String>) {
		this.targets = targets;
		this.jsonDir = jsonDir;
	}
}
