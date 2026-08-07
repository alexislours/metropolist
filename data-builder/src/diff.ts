import type { Line, Station, RouteVariant, LineStop, Transfer, OutputData, DiffDetail } from "./types";

/** Return a list of "field: old -> new" strings for every changed key. */
function fieldDiffs<T extends object>(
  prev: T,
  next: T,
  keys: (keyof T & string)[],
): string[] {
  const diffs: string[] = [];
  for (const k of keys) {
    const p = prev[k];
    const n = next[k];
    if (p !== n) {
      diffs.push(`${k}: ${JSON.stringify(p)} → ${JSON.stringify(n)}`);
    }
  }
  return diffs;
}

const LINE_KEYS: (keyof Line & string)[] = [
  "shortName", "longName", "mode", "submode", "color", "textColor",
  "operatorName", "networkName", "status", "isAccessible",
  "groupId", "groupName",
];

const STATION_KEYS: (keyof Station & string)[] = [
  "name", "fareZone", "town", "postalCode",
  "isAccessible", "hasAudibleSignals", "hasVisualSigns",
];

/** Minimum coordinate change (~1 m) to count as a real move. */
const GEO_EPSILON = 0.00001;

function stationFieldDiffs(prev: Station, next: Station): string[] {
  const diffs = fieldDiffs(prev, next, STATION_KEYS);
  const latDelta = Math.abs(prev.latitude - next.latitude);
  const lonDelta = Math.abs(prev.longitude - next.longitude);
  if (latDelta >= GEO_EPSILON || lonDelta >= GEO_EPSILON) {
    diffs.push(`latitude: ${prev.latitude} → ${next.latitude}`);
    diffs.push(`longitude: ${prev.longitude} → ${next.longitude}`);
  }
  return diffs;
}

const RV_KEYS: (keyof RouteVariant & string)[] = [
  "lineId", "direction", "headsign", "stationCount",
];

function partition<T extends { id: string }>(
  prev: T[],
  next: T[],
  changesFor: (prev: T, next: T) => string[],
): { added: T[]; removed: T[]; modified: { item: T; previous: T; changes: string[] }[] } {
  const prevById = new Map(prev.map((x) => [x.id, x]));
  const nextById = new Map(next.map((x) => [x.id, x]));

  const modified: { item: T; previous: T; changes: string[] }[] = [];
  for (const item of next) {
    const before = prevById.get(item.id);
    if (!before) continue;
    const changes = changesFor(before, item);
    if (changes.length > 0) modified.push({ item, previous: before, changes });
  }

  return {
    added: next.filter((x) => !prevById.has(x.id)),
    removed: prev.filter((x) => !nextById.has(x.id)),
    modified,
  };
}

function countKeyedChanges<T>(prev: T[], next: T[], key: (x: T) => string): { added: number; removed: number } {
  const prevKeys = new Set(prev.map(key));
  const nextKeys = new Set(next.map(key));
  return {
    added: next.filter((x) => !prevKeys.has(key(x))).length,
    removed: prev.filter((x) => !nextKeys.has(key(x))).length,
  };
}

export function computeDiff(previousData: OutputData, output: OutputData): DiffDetail {
  const lines = partition(previousData.lines, output.lines, (p, n) => fieldDiffs(p, n, LINE_KEYS));
  const stations = partition(previousData.stations, output.stations, stationFieldDiffs);
  const routeVariants = partition(previousData.routeVariants, output.routeVariants, (p, n) =>
    fieldDiffs(p, n, RV_KEYS),
  );

  const lsKey = (ls: LineStop) => `${ls.routeVariantId}|${ls.stationId}|${ls.order}`;
  const trKey = (t: Transfer) => `${t.fromStationId}|${t.toStationId}`;

  const counts = (d: OutputData) => ({
    lines: d.lines.length,
    stations: d.stations.length,
    routeVariants: d.routeVariants.length,
    lineStops: d.lineStops.length,
    transfers: d.transfers.length,
  });

  return {
    lines: {
      added: lines.added,
      removed: lines.removed,
      modified: lines.modified.map(({ item, changes }) => ({ line: item, changes })),
    },
    stations: {
      added: stations.added,
      removed: stations.removed,
      modified: stations.modified.map(({ item, previous, changes }) => ({ station: item, previous, changes })),
    },
    routeVariants: {
      added: routeVariants.added,
      removed: routeVariants.removed,
      modified: routeVariants.modified.map(({ item, changes }) => ({ rv: item, changes })),
    },
    lineStops: countKeyedChanges(previousData.lineStops, output.lineStops, lsKey),
    transfers: countKeyedChanges(previousData.transfers, output.transfers, trKey),
    previousCounts: counts(previousData),
    nextCounts: counts(output),
  };
}

function header(label: string, before: number, after: number, extra = ""): string {
  const delta = after - before;
  const sign = delta > 0 ? "+" : "";
  return `\n${label}: ${before} → ${after} (${sign}${delta}${extra})`;
}

function printLines(detail: DiffDetail, changelog: string[]): void {
  const { added, removed, modified } = detail.lines;
  if (added.length === 0 && removed.length === 0 && modified.length === 0) {
    console.log(`\nLines: ${detail.nextCounts.lines} (no changes)`);
    return;
  }
  console.log(header("Lines", detail.previousCounts.lines, detail.nextCounts.lines));

  const summariseByMode = (items: Line[], verb: string) => {
    const byMode = new Map<string, Line[]>();
    for (const l of items) byMode.set(l.mode, [...(byMode.get(l.mode) ?? []), l]);
    for (const [mode, group] of byMode) {
      const names = group.map((l) => l.shortName).join(", ");
      changelog.push(`${verb} ${mode} line${group.length > 1 ? "s" : ""}: ${names}`);
    }
  };

  if (added.length > 0) {
    console.log(`  New (${added.length}):`);
    for (const l of added) console.log(`    + ${l.id} "${l.shortName}" [${l.mode}]`);
    summariseByMode(added, "Added");
  }
  if (removed.length > 0) {
    console.log(`  Deleted (${removed.length}):`);
    for (const l of removed) console.log(`    - ${l.id} "${l.shortName}" [${l.mode}]`);
    summariseByMode(removed, "Removed");
  }
  if (modified.length > 0) {
    console.log(`  Modified (${modified.length}):`);
    for (const { line, changes } of modified) {
      console.log(`    ~ ${line.id} "${line.shortName}" [${line.mode}]`);
      for (const c of changes) console.log(`        ${c}`);
    }
    changelog.push(`Updated info for ${modified.length} line${modified.length > 1 ? "s" : ""}`);
  }
}

function printStations(detail: DiffDetail, changelog: string[]): void {
  const { added, removed, modified } = detail.stations;
  if (added.length === 0 && removed.length === 0 && modified.length === 0) {
    console.log(`\nStations: ${detail.nextCounts.stations} (no changes)`);
    return;
  }
  console.log(header("Stations", detail.previousCounts.stations, detail.nextCounts.stations));

  const label = (s: Station) => `${s.id} "${s.name}"${s.town ? ` (${s.town})` : ""}`;

  if (added.length > 0) {
    console.log(`  New (${added.length}):`);
    for (const s of added) console.log(`    + ${label(s)}`);
    changelog.push(`Added ${added.length} new station${added.length > 1 ? "s" : ""}`);
  }
  if (removed.length > 0) {
    console.log(`  Deleted (${removed.length}):`);
    for (const s of removed) console.log(`    - ${label(s)}`);
    changelog.push(`Removed ${removed.length} station${removed.length > 1 ? "s" : ""}`);
  }
  if (modified.length > 0) {
    console.log(`  Modified (${modified.length}):`);
    for (const { station, changes } of modified) {
      console.log(`    ~ ${label(station)}`);
      for (const c of changes) console.log(`        ${c}`);
    }
    const fields = modified.flatMap((m) => m.changes.map((c) => c.split(":")[0]));
    const parts: string[] = [];
    if (fields.some((f) => f === "latitude" || f === "longitude")) parts.push("locations");
    if (fields.some((f) => f === "isAccessible" || f === "hasAudibleSignals" || f === "hasVisualSigns")) {
      parts.push("accessibility info");
    }
    const plural = modified.length > 1 ? "s" : "";
    changelog.push(
      parts.length > 0
        ? `Updated station ${parts.join(" and ")} (${modified.length} station${plural})`
        : `Updated ${modified.length} station${plural}`,
    );
  }
}

function printRouteVariants(detail: DiffDetail, output: OutputData, previousData: OutputData, changelog: string[]): void {
  const { added, removed, modified } = detail.routeVariants;
  if (added.length === 0 && removed.length === 0 && modified.length === 0) {
    console.log(`\nRoute variants: ${detail.nextCounts.routeVariants} (no changes)`);
    return;
  }

  const lineNameById = new Map<string, string>();
  for (const l of output.lines) lineNameById.set(l.id, l.shortName);
  for (const l of previousData.lines) {
    if (!lineNameById.has(l.id)) lineNameById.set(l.id, l.shortName);
  }
  const rvLabel = (rv: RouteVariant) => `${rv.id} [${lineNameById.get(rv.lineId) ?? rv.lineId}] → ${rv.headsign}`;

  console.log(header("Route variants", detail.previousCounts.routeVariants, detail.nextCounts.routeVariants));

  if (added.length > 0) {
    console.log(`  New (${added.length}):`);
    for (const rv of added) console.log(`    + ${rvLabel(rv)}`);
  }
  if (removed.length > 0) {
    console.log(`  Deleted (${removed.length}):`);
    for (const rv of removed) console.log(`    - ${rvLabel(rv)}`);
  }
  if (modified.length > 0) {
    console.log(`  Modified (${modified.length}):`);
    for (const { rv, changes } of modified) {
      console.log(`    ~ ${rvLabel(rv)}`);
      for (const c of changes) console.log(`        ${c}`);
    }
  }
  if (added.length > 0 || removed.length > 0) {
    const parts: string[] = [];
    if (added.length > 0) parts.push(`${added.length} added`);
    if (removed.length > 0) parts.push(`${removed.length} removed`);
    changelog.push(`Route changes (${parts.join(", ")})`);
  }
}

export function printDiff(previousData: OutputData, output: OutputData): DiffDetail {
  const detail = computeDiff(previousData, output);
  const changelog: string[] = [];

  console.log("\n" + "─".repeat(60));
  console.log("  CHANGES SINCE LAST BUILD");
  console.log("─".repeat(60));

  printLines(detail, changelog);
  printStations(detail, changelog);
  printRouteVariants(detail, output, previousData, changelog);

  if (detail.lineStops.added === 0 && detail.lineStops.removed === 0) {
    console.log(`\nLine stops: ${detail.nextCounts.lineStops} (no changes)`);
  } else {
    const { added, removed } = detail.lineStops;
    console.log(header("Line stops", detail.previousCounts.lineStops, detail.nextCounts.lineStops, `, +${added} new, -${removed} removed`));
    changelog.push(`Updated stop sequences (${added} added, ${removed} removed)`);
  }

  if (detail.transfers.added === 0 && detail.transfers.removed === 0) {
    console.log(`Transfers: ${detail.nextCounts.transfers} (no changes)`);
  } else {
    const { added, removed } = detail.transfers;
    console.log(header("Transfers", detail.previousCounts.transfers, detail.nextCounts.transfers, `, +${added} new, -${removed} removed`).trimStart());
    changelog.push(`Updated transfer connections (${added} added, ${removed} removed)`);
  }

  console.log("─".repeat(60));

  if (changelog.length > 0) {
    console.log("\n  Changelog:");
    for (const entry of changelog) console.log(`  • ${entry}`);
  } else {
    console.log("\n  No data changes.");
  }
  console.log("");

  return detail;
}
