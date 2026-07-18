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
 * Host mode (WHY_BENCHKIT_RESULT set):
 *   - Exposes window.benchkitComplete(result) — prefer a plain object
 *     (Puppeteer JSON-clones it); string JSON is also accepted.
 *   - Sets window.benchkitResultPath so the suite enters host handoff mode.
 *   - Writes the result JSON to WHY_BENCHKIT_RESULT on the host filesystem.
 *
 * Standalone `--json` in the browser:
 *   - Exposes window.benchkitWriteFile(path, content) for JsonWriter.
 */
const fs = require("fs");

module.exports = {
	async beforeGoto(page) {
		await page.exposeFunction("benchkitWriteFile", (filePath, content) => {
			// Host-side write: path is relative to Node cwd (consumer project), not the page URL.
			fs.writeFileSync(filePath, content, "utf8");
		});

		const resultPath = process.env.WHY_BENCHKIT_RESULT;
		if (resultPath) {
			await page.exposeFunction("benchkitComplete", (result) => {
				const content =
					typeof result === "string" ? result : JSON.stringify(result);
				fs.writeFileSync(resultPath, content, "utf8");
			});
			await page.evaluateOnNewDocument((path) => {
				window.benchkitResultPath = path;
			}, resultPath);
		}
	},
};
