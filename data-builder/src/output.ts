import type { Line, Station, RouteVariant, LineStop, Transfer, OutputData, DatasetChanges } from "./types";
import { log } from "./helpers";
import { printDiff } from "./diff";
import { buildDiffSummary } from "./changes";

export function buildDataVersion(now: Date): number {
  const pad = (n: number) => String(n).padStart(2, "0");
  const stamp =
    `${now.getUTCFullYear()}` +
    `${pad(now.getUTCMonth() + 1)}` +
    `${pad(now.getUTCDate())}` +
    `${pad(now.getUTCHours())}` +
    `${pad(now.getUTCMinutes())}`;
  return Number(stamp);
}

const CHANGES_PATH = "./metropolist-changes.json";

const EMPTY_CHANGES: DatasetChanges = {
  delta: {
    linesAdded: 0, linesRemoved: 0, linesModified: 0,
    stationsAdded: 0, stationsRemoved: 0, stationsModified: 0,
    routeVariantsChanged: 0, transfersChanged: 0,
  },
  highlights: [],
};

export function sortData(
  lines: Line[],
  stations: Station[],
  routeVariants: RouteVariant[],
  lineStops: LineStop[],
  transfers: Transfer[],
): void {
  lines.sort((a, b) => a.id.localeCompare(b.id));
  stations.sort((a, b) => a.id.localeCompare(b.id));
  routeVariants.sort((a, b) => a.id.localeCompare(b.id));
  lineStops.sort((a, b) => {
    const rv = a.routeVariantId.localeCompare(b.routeVariantId);
    if (rv !== 0) return rv;
    return a.order - b.order;
  });
  transfers.sort((a, b) => {
    const f = a.fromStationId.localeCompare(b.fromStationId);
    if (f !== 0) return f;
    return a.toStationId.localeCompare(b.toStationId);
  });
}

export async function writeOutput(
  lines: Line[],
  stations: Station[],
  routeVariants: RouteVariant[],
  lineStops: LineStop[],
  transfers: Transfer[],
  outputPath: string,
): Promise<OutputData> {
  log("Step 9: Sorting and writing output...");

  sortData(lines, stations, routeVariants, lineStops, transfers);

  const now = new Date();
  const output: OutputData = {
    dataVersion: buildDataVersion(now),
    generatedAt: now.toISOString(),
    sourceFiles: {
      gtfs: "IDFM-gtfs",
      referentiel: "referentiel-des-lignes.json",
      arrets: "arrets.json",
      arretsLignes: "arrets-lignes.json",
    },
    lines,
    stations,
    lineStops,
    routeVariants,
    transfers,
  };

  // Load existing data for comparison before overwriting
  let previousData: OutputData | null = null;
  const outputFile = Bun.file(outputPath);
  if (await outputFile.exists()) {
    try {
      previousData = JSON.parse(await outputFile.text()) as OutputData;
      log("  → Loaded previous data for comparison");
    } catch {
      log("  → Could not parse previous data, skipping comparison");
    }
  } else {
    log("  → No previous data found, first build");
  }

  await Bun.write(outputPath, JSON.stringify(output, null, 2));
  const fileSize = Bun.file(outputPath).size;
  log(`  → Written to ${outputPath} (${(fileSize / 1024 / 1024).toFixed(1)} MB)`);

  const changes = previousData ? buildDiffSummary(printDiff(previousData, output)) : EMPTY_CHANGES;
  await Bun.write(CHANGES_PATH, JSON.stringify(changes, null, 2));
  log(`  → Change summary written to ${CHANGES_PATH}`);

  return output;
}

export function printSummary(
  lines: Line[],
  stations: Station[],
  routeVariants: RouteVariant[],
  lineStops: LineStop[],
  transfers: Transfer[],
  prunedLines: Line[],
  linesWithStops: Set<string>,
  elapsed: string,
): void {
  console.log("\n" + "═".repeat(60));
  console.log("  METROPOLIST DATA BUILD — SUMMARY");
  console.log("═".repeat(60));

  // Lines by mode
  const linesByMode = new Map<string, number>();
  for (const line of lines) {
    linesByMode.set(line.mode, (linesByMode.get(line.mode) ?? 0) + 1);
  }
  console.log("\nLines by mode:");
  for (const [mode, count] of [...linesByMode.entries()].sort()) {
    console.log(`  ${mode.padEnd(15)} ${count}`);
  }

  // Lines by status + skipped
  const zeroStationSkipped = prunedLines.filter((l) => !linesWithStops.has(l.id)).length;
  const upcomingSkipped = prunedLines.filter((l) => l.status === "upcoming").length;
  console.log(`\nLines: ${lines.length} kept, ${prunedLines.length} skipped (${zeroStationSkipped} no stations, ${upcomingSkipped} upcoming)`);

  console.log(`Stations: ${stations.length}`);
  console.log(`Route variants: ${routeVariants.length}`);
  console.log(`Line stops: ${lineStops.length}`);
  console.log(`Transfers: ${transfers.length}`);

  // Orphan stations (should be 0 after pruning)
  const stationsWithStops = new Set(lineStops.map((ls) => ls.stationId));
  const orphanStations = stations.filter((s) => !stationsWithStops.has(s.id));
  console.log(`Orphan stations (should be 0): ${orphanStations.length}`);

  console.log(`\nCompleted in ${elapsed}s`);
  console.log("═".repeat(60));
}
