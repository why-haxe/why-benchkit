/**
 * Packaged travix hooks for why-benchkit browser `js` runs.
 *
 * Host (Phase 6+) must set TRAVIX_CONFIG_DIR to the absolute path of this
 * packaged `.travix/` directory (the config root), e.g.:
 *
 *   TRAVIX_CONFIG_DIR=/absolute/path/to/why-benchkit/.travix
 *
 * Travix then loads `$TRAVIX_CONFIG_DIR/js/hooks.js`. That env var *replaces*
 * cwd `.travix` for the run (not a merge). Do not rely on writing into the
 * consumer's `.travix/`, and do not use deprecated bin/js/run.js overrides.
 *
 * Exposes window.benchkitWriteFile(path, content) so suite JSON can be written
 * from the page via host-side fs.writeFileSync.
 */
const fs = require("fs");

module.exports = {
	async beforeGoto(page) {
		await page.exposeFunction("benchkitWriteFile", (filePath, content) => {
			// Host-side write: path is relative to Node cwd (consumer project), not the page URL.
			fs.writeFileSync(filePath, content, "utf8");
		});
	},
};
