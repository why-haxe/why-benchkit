(function () {
	"use strict";
  
	const cfg = window.WHY_BENCHKIT || {};
	const JSON_BASE = typeof cfg.jsonBase === "string" ? cfg.jsonBase : "./";
  
	const statusEl = document.getElementById("status");
	const controlsEl = document.getElementById("controls");
	const emptyEl = document.getElementById("empty");
	const chartsEl = document.getElementById("charts");
	const selHaxe = document.getElementById("sel-haxe");
	const selTarget = document.getElementById("sel-target");
	const selSuite = document.getElementById("sel-suite");
	const dirtyLabel = document.getElementById("dirty-label");
	const chkDirty = document.getElementById("chk-dirty");
	const jsonBaseEl = document.getElementById("json-base");
  
	if (jsonBaseEl) jsonBaseEl.textContent = JSON_BASE;
  
	/** @type {{ id: string, timestamp: number, files: string[] }[]} */
	let commits = [];
	/** @type {{ timestamp: number, files: string[] } | null} */
	let dirty = null;
	/** @type {Map<string, any>} */
	const resultCache = new Map();
	/** @type {import("chart.js").Chart[]} */
	const chartInstances = [];
	let loadGen = 0;
  
	function setStatus(msg, isErr) {
	  statusEl.className = isErr ? "status err" : "status";
	  statusEl.textContent = msg;
	}
  
	function url(rel) {
	  return JSON_BASE + String(rel).replace(/^\\/+/, "");
	}
  
	async function fetchJson(rel) {
	  const res = await fetch(url(rel));
	  if (!res.ok) {
		const err = new Error("HTTP " + res.status + " for " + rel);
		err.status = res.status;
		throw err;
	  }
	  return res.json();
	}
  
	function shortSha(id) {
	  if (!id) return "";
	  return id.length > 10 ? id.slice(0, 10) : id;
	}
  
	function parseFileEntry(file) {
	  const m = String(file).match(/^([^/]+)\\/([^/]+)\\.json$/);
	  if (!m) return null;
	  return { haxe: m[1], target: m[2], file: file };
	}
  
	function fileFor(haxe, target) {
	  return haxe + "/" + target + ".json";
	}
  
	function discoverPairs(fileLists) {
	  const haxes = new Set();
	  const targets = new Set();
	  for (const files of fileLists) {
		if (!files) continue;
		for (const f of files) {
		  const p = parseFileEntry(f);
		  if (!p) continue;
		  haxes.add(p.haxe);
		  targets.add(p.target);
		}
	  }
	  return {
		haxes: Array.from(haxes).sort(),
		targets: Array.from(targets).sort()
	  };
	}
  
	function fillSelect(sel, values, preferred) {
	  sel.textContent = "";
	  if (!values.length) {
		const opt = document.createElement("option");
		opt.value = "";
		opt.textContent = "(none)";
		sel.appendChild(opt);
		sel.disabled = true;
		return;
	  }
	  sel.disabled = false;
	  for (const v of values) {
		const opt = document.createElement("option");
		opt.value = v;
		opt.textContent = v;
		sel.appendChild(opt);
	  }
	  if (preferred && values.indexOf(preferred) >= 0) sel.value = preferred;
	  else sel.value = values[0];
	}
  
	function destroyCharts() {
	  while (chartInstances.length) {
		const c = chartInstances.pop();
		try { c.destroy(); } catch (e) { /* ignore */ }
	  }
	  chartsEl.textContent = "";
	}
  
	function setEmpty(msg) {
	  destroyCharts();
	  if (msg) {
		emptyEl.hidden = false;
		emptyEl.textContent = msg;
	  } else {
		emptyEl.hidden = true;
		emptyEl.textContent = "";
	  }
	}
  
	function opsPerSec(durationMs, iterations) {
	  if (typeof durationMs !== "number" || !isFinite(durationMs) || durationMs <= 0) return null;
	  if (typeof iterations !== "number" || !isFinite(iterations) || iterations <= 0) return null;
	  return iterations / (durationMs / 1000);
	}
  
	function findSuite(doc, suiteName) {
	  if (!doc || !Array.isArray(doc.results)) return null;
	  for (const s of doc.results) {
		if (s && s.name === suiteName) return s;
	  }
	  return null;
	}
  
	function findMeasure(suite, measureName) {
	  if (!suite || !Array.isArray(suite.results)) return null;
	  for (const m of suite.results) {
		if (m && m.name === measureName) return m;
	  }
	  return null;
	}
  
	async function loadResult(prefix, file) {
	  const rel = prefix + file;
	  if (resultCache.has(rel)) return resultCache.get(rel);
	  try {
		const doc = await fetchJson(rel);
		resultCache.set(rel, doc);
		return doc;
	  } catch (e) {
		resultCache.set(rel, null);
		return null;
	  }
	}
  
	async function docsForSelection(haxe, target, includeDirty) {
	  const file = fileFor(haxe, target);
	  const rows = [];
	  for (const c of commits) {
		const has = Array.isArray(c.files) && c.files.indexOf(file) >= 0;
		let doc = null;
		if (has) doc = await loadResult(c.id + "/", file);
		rows.push({
		  id: c.id,
		  label: shortSha(c.id),
		  fullId: c.id,
		  timestamp: c.timestamp,
		  dirty: false,
		  doc: doc
		});
	  }
	  if (includeDirty && dirty) {
		const has = Array.isArray(dirty.files) && dirty.files.indexOf(file) >= 0;
		let doc = null;
		if (has) doc = await loadResult("_dirty/", file);
		rows.push({
		  id: "_dirty",
		  label: "_dirty",
		  fullId: "_dirty",
		  timestamp: dirty.timestamp,
		  dirty: true,
		  doc: doc
		});
	  }
	  return rows;
	}
  
	function suiteNamesFromRows(rows) {
	  const names = new Set();
	  for (const row of rows) {
		if (!row.doc || !Array.isArray(row.doc.results)) continue;
		for (const s of row.doc.results) {
		  if (s && typeof s.name === "string") names.add(s.name);
		}
	  }
	  return Array.from(names).sort();
	}
  
	function measureNamesForSuite(rows, suiteName) {
	  const names = [];
	  const seen = new Set();
	  for (const row of rows) {
		const suite = findSuite(row.doc, suiteName);
		if (!suite || !Array.isArray(suite.results)) continue;
		for (const m of suite.results) {
		  if (!m || typeof m.name !== "string" || seen.has(m.name)) continue;
		  seen.add(m.name);
		  names.push(m.name);
		}
	  }
	  return names;
	}
  
	function fmtTime(ms) {
	  if (typeof ms !== "number" || !isFinite(ms)) return String(ms);
	  try { return new Date(ms).toISOString(); }
	  catch (e) { return String(ms); }
	}
  
	function renderCharts(rows, suiteName) {
	  const measures = measureNamesForSuite(rows, suiteName);
	  if (!measures.length) {
		setEmpty("No measurements for suite \\"" + suiteName + "\\" with the current filters.");
		return;
	  }
  
	  setEmpty(null);
	  const labels = rows.map(r => r.label);
	  const cleanColor = "rgb(11, 87, 208)";
	  const dirtyColor = "rgb(180, 83, 9)";
  
	  for (const measureName of measures) {
		const durations = [];
		const pointMeta = [];
		let anyPoint = false;
		for (const row of rows) {
		  const suite = findSuite(row.doc, suiteName);
		  const m = findMeasure(suite, measureName);
		  if (m && typeof m.duration === "number" && isFinite(m.duration)) {
			durations.push(m.duration);
			anyPoint = true;
			pointMeta.push({
			  iterations: m.iterations,
			  warmup: m.warmup,
			  ops: opsPerSec(m.duration, m.iterations),
			  dirty: row.dirty,
			  fullId: row.fullId,
			  timestamp: row.timestamp
			});
		  } else {
			durations.push(null);
			pointMeta.push({
			  iterations: null,
			  warmup: null,
			  ops: null,
			  dirty: row.dirty,
			  fullId: row.fullId,
			  timestamp: row.timestamp
			});
		  }
		}
  
		const card = document.createElement("div");
		card.className = "chart-card";
		const h2 = document.createElement("h2");
		h2.textContent = measureName;
		card.appendChild(h2);
		const meta = document.createElement("p");
		meta.className = "chart-meta";
		meta.textContent = anyPoint
		  ? "Duration (ms) across commits" + (rows.some(r => r.dirty) ? " (+ dirty overlay)" : "")
		  : "No data points for this measurement.";
		card.appendChild(meta);
  
		if (!anyPoint) {
		  chartsEl.appendChild(card);
		  continue;
		}
  
		const wrap = document.createElement("div");
		wrap.className = "chart-wrap";
		const canvas = document.createElement("canvas");
		wrap.appendChild(canvas);
		card.appendChild(wrap);
		chartsEl.appendChild(card);
  
		const pointColors = pointMeta.map(p => p.dirty ? dirtyColor : cleanColor);
		const chart = new Chart(canvas.getContext("2d"), {
		  type: "line",
		  data: {
			labels: labels,
			datasets: [{
			  label: "duration (ms)",
			  data: durations,
			  borderColor: cleanColor,
			  backgroundColor: "rgba(11, 87, 208, 0.12)",
			  pointBackgroundColor: pointColors,
			  pointBorderColor: pointColors,
			  spanGaps: false,
			  tension: 0.15
			}]
		  },
		  options: {
			responsive: true,
			maintainAspectRatio: false,
			interaction: { mode: "index", intersect: false },
			plugins: {
			  legend: { display: false },
			  tooltip: {
				callbacks: {
				  title: function (items) {
					const i = items[0] && items[0].dataIndex;
					const p = pointMeta[i];
					if (!p) return "";
					return p.fullId + (p.dirty ? " (dirty)" : "");
				  },
				  afterBody: function (items) {
					const i = items[0] && items[0].dataIndex;
					const p = pointMeta[i];
					if (!p) return [];
					const lines = ["timestamp: " + fmtTime(p.timestamp)];
					if (p.iterations != null) lines.push("iterations: " + p.iterations);
					if (p.warmup != null) lines.push("warmup: " + p.warmup);
					if (p.ops != null) lines.push("ops/sec: " + p.ops.toFixed(1));
					return lines;
				  }
				}
			  }
			},
			scales: {
			  x: {
				title: { display: true, text: "commit" },
				ticks: { maxRotation: 45, minRotation: 0 }
			  },
			  y: {
				title: { display: true, text: "duration (ms)" },
				beginAtZero: true
			  }
			}
		  }
		});
		chartInstances.push(chart);
	  }
	}
  
	async function refreshSuitesAndCharts() {
	  const gen = ++loadGen;
	  const haxe = selHaxe.value;
	  const target = selTarget.value;
	  if (!haxe || !target) {
		fillSelect(selSuite, [], null);
		setEmpty("No haxe version / target combinations found in commit manifests.");
		return;
	  }
  
	  const includeDirty = !!(chkDirty && chkDirty.checked && dirty);
	  setStatus("Loading results…", false);
	  const rows = await docsForSelection(haxe, target, includeDirty);
	  if (gen !== loadGen) return;
	  const suites = suiteNamesFromRows(rows);
	  const prevSuite = selSuite.value;
	  fillSelect(selSuite, suites, prevSuite);
  
	  const hasAnyDoc = rows.some(r => r.doc);
	  if (!hasAnyDoc) {
		setEmpty("No result JSON for " + haxe + " / " + target + " across the selected commits.");
		setStatus("Ready.", false);
		return;
	  }
	  if (!suites.length) {
		setEmpty("Result files loaded, but no suites found for " + haxe + " / " + target + ".");
		setStatus("Ready.", false);
		return;
	  }
  
	  renderCharts(rows, selSuite.value);
	  setStatus("Ready.", false);
	}
  
	async function onFilterChange() {
	  try {
		await refreshSuitesAndCharts();
	  } catch (e) {
		setStatus("Failed to update charts: " + String(e && e.message ? e.message : e), true);
	  }
	}
  
	async function main() {
	  if (typeof Chart === "undefined") {
		setStatus("Chart.js failed to load from CDN. Check network / CSP.", true);
		return;
	  }
  
	  try {
		const root = await fetchJson("manifest.json");
		const ids = Array.isArray(root.commits) ? root.commits : [];
		commits = [];
		for (const id of ids) {
		  try {
			const man = await fetchJson(id + "/manifest.json");
			commits.push({
			  id: id,
			  timestamp: typeof man.timestamp === "number" ? man.timestamp : 0,
			  files: Array.isArray(man.files) ? man.files : []
			});
		  } catch (e) {
			commits.push({ id: id, timestamp: 0, files: [] });
		  }
		}
  
		dirty = null;
		try {
		  const d = await fetchJson("_dirty/manifest.json");
		  dirty = {
			timestamp: typeof d.timestamp === "number" ? d.timestamp : 0,
			files: Array.isArray(d.files) ? d.files : []
		  };
		} catch (e) {
		  if (!(e && e.status === 404)) {
			// Non-404 dirty probe failure is non-fatal; leave overlay unavailable.
			console.warn("Dirty probe failed:", e);
		  }
		}
  
		const pairs = discoverPairs(commits.map(c => c.files).concat(dirty ? [dirty.files] : []));
		controlsEl.hidden = false;
		fillSelect(selHaxe, pairs.haxes, null);
		fillSelect(selTarget, pairs.targets, null);
  
		if (dirty) {
		  dirtyLabel.hidden = false;
		  chkDirty.checked = false;
		} else {
		  dirtyLabel.hidden = true;
		}
  
		selHaxe.addEventListener("change", onFilterChange);
		selTarget.addEventListener("change", onFilterChange);
		selSuite.addEventListener("change", onFilterChange);
		if (chkDirty) chkDirty.addEventListener("change", onFilterChange);
  
		if (!commits.length && !dirty) {
		  setEmpty("No clean commits in root manifest.json and no _dirty overlay.");
		  setStatus("Ready.", false);
		  return;
		}
		if (!pairs.haxes.length || !pairs.targets.length) {
		  setEmpty("Commit manifests list no haxe/target result files.");
		  setStatus("Ready.", false);
		  return;
		}
  
		await refreshSuitesAndCharts();
	  } catch (e) {
		setStatus("Failed to load root manifest.json: " + String(e && e.message ? e.message : e)
		  + "\\nServe the page and JSON tree over HTTP from a common origin.", true);
	  }
	}
  
	main();
  })();