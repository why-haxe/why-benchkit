package why.benchkit.host;

/**
	Process-exit status for a shared host multi-target run.

	`Ok` / `Failed` map to exit codes 0 / 1 for CLI edges. Travix may still
	call `Sys.exit` on toolchain/build failure before this value is returned.
**/
enum abstract HostRunStatus(Int) from Int to Int {
	final Ok = 0;
	final Failed = 1;
}
