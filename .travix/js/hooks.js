/**
 * Packaged travix hooks for why-benchkit browser `js` runs.
 *
 * Host must set TRAVIX_CONFIG_DIR to the absolute path of this packaged
 * `.travix/` directory (the config root), e.g.:
 *
 *   TRAVIX_CONFIG_DIR=/absolute/path/to/why-benchkit/.travix
 *
 * Travix then loads `$TRAVIX_CONFIG_DIR/js/hooks.js`. That env var *replaces*
 * cwd `.travix` for the run (not a merge). Do not rely on writing into the
 * consumer's `.travix/`, and do not use deprecated bin/js/run.js overrides.
 *
 * Config inject (WHY_BENCHKIT_CONFIG):
 *   - Parses host env JSON and sets window.why.benchkit before page scripts run
 *     (same shape as native Config.load). Suite reporting stays in-page.
 *
 * JsonReporter bridge:
 *   - Exposes window.benchkitWriteFile(path, content) so JsonWriter can persist
 *     output from the browser to the host filesystem.
 */
const fs = require("fs");

module.exports = {
	async beforeGoto(page) {
		await page.exposeFunction("benchkitWriteFile", (filePath, content) => {
			// Host-side write: path is relative to Node cwd (consumer project), not the page URL.
			fs.writeFileSync(filePath, content, "utf8");
		});

		await page.evaluateOnNewDocument((config) => {
			window.why = window.why || {};
			window.why.benchkit = config;
		}, getConfig());
	},
};

function getConfig() {
	try {
		return JSON.parse(process.env.WHY_BENCHKIT_CONFIG);
	} catch (e) {
		throw new Error(
			"why-benchkit: invalid WHY_BENCHKIT_CONFIG JSON for browser inject: " +
				String(e)
		);
	}
}
