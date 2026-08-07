#!/usr/bin/env bun
import { readFileSync, writeFileSync, existsSync } from "node:fs";

const MANIFEST_PATH = "dist/transit-manifest.json";
const MANIFEST_VERSION = 1;
const HISTORY_PER_SCHEMA = 3;

const STATION_DROP_LIMIT = 0.02;
const LINE_DROP_LIMIT = 0.05;
const SIZE_DEVIATION_LIMIT = 0.2;

interface StoreCounts {
  lines: number;
  stations: number;
  routeVariants: number;
  lineStops: number;
  transfers: number;
}

interface StoreInfo {
  schemaVersion: number;
  dataVersion: number;
  generatedAt: string;
  sha256: string;
  byteSize: number;
  counts: StoreCounts;
  modelHash: string;
}

interface ManifestEntry {
  schemaVersion: number;
  dataVersion: number;
  generatedAt: string;
  url: string;
  byteSize: number;
  sha256: string;
  modelHash: string;
  counts: StoreCounts;
  minimumAppBuild?: number;
  changes: unknown;
}

interface Manifest {
  manifestVersion: number;
  updatedAt: string;
  datasets: ManifestEntry[];
}

function fail(message: string): never {
  console.error(`SAFEGUARD FAILED: ${message}`);
  process.exit(1);
}

function readJSON<T>(path: string): T {
  return JSON.parse(readFileSync(path, "utf8")) as T;
}

function loadManifest(): Manifest {
  if (!existsSync(MANIFEST_PATH)) {
    return { manifestVersion: MANIFEST_VERSION, updatedAt: "", datasets: [] };
  }
  return readJSON<Manifest>(MANIFEST_PATH);
}

function checkSchemaConstant(info: StoreInfo): void {
  const source = readFileSync("store-builder/Sources/TransitModels/TransitSchema.swift", "utf8");
  const match = source.match(/static let version = (\d+)/);
  if (!match) fail("could not read TransitSchema.version");
  const declared = Number(match[1]);
  if (declared !== info.schemaVersion) {
    fail(`TransitSchema.version is ${declared} but the store says ${info.schemaVersion}`);
  }
}

function checkModelHash(info: StoreInfo, previous: ManifestEntry | undefined): void {
  if (!previous) return;
  if (previous.modelHash === info.modelHash) return;
  if (previous.schemaVersion === info.schemaVersion) {
    fail(
      `Core Data model changed (${previous.modelHash.slice(0, 12)} -> ${info.modelHash.slice(0, 12)}) ` +
        `but TransitSchema.version is still ${info.schemaVersion}. Bump it and ship an app release first.`,
    );
  }
}

function checkThresholds(info: StoreInfo, previous: ManifestEntry | undefined, force: boolean): void {
  const empty = Object.entries(info.counts).filter(([, value]) => value === 0);
  if (empty.length > 0) fail(`empty table(s): ${empty.map(([k]) => k).join(", ")}`);

  if (!previous) return;

  const stationDrop = 1 - info.counts.stations / previous.counts.stations;
  const lineDrop = 1 - info.counts.lines / previous.counts.lines;
  const sizeDeviation = Math.abs(info.byteSize - previous.byteSize) / previous.byteSize;

  const problems: string[] = [];
  if (stationDrop > STATION_DROP_LIMIT) {
    problems.push(`stations dropped ${(stationDrop * 100).toFixed(1)}% (limit ${STATION_DROP_LIMIT * 100}%)`);
  }
  if (lineDrop > LINE_DROP_LIMIT) {
    problems.push(`lines dropped ${(lineDrop * 100).toFixed(1)}% (limit ${LINE_DROP_LIMIT * 100}%)`);
  }
  if (sizeDeviation > SIZE_DEVIATION_LIMIT) {
    problems.push(`size deviated ${(sizeDeviation * 100).toFixed(1)}% (limit ${SIZE_DEVIATION_LIMIT * 100}%)`);
  }

  if (problems.length === 0) return;
  if (force) {
    console.warn(`Threshold guards overridden by force: ${problems.join("; ")}`);
    return;
  }
  fail(problems.join("; "));
}

function main(): void {
  const [, , infoPath, changesPath, assetURL, forceFlag, minBuildFlag] = process.argv;
  if (!infoPath || !changesPath || !assetURL) {
    console.error(
      "usage: build-manifest.ts <transit-info.json> <metropolist-changes.json> <assetURL> [force] [minAppBuild]",
    );
    process.exit(2);
  }

  const info = readJSON<StoreInfo>(infoPath);
  const changes = readJSON<unknown>(changesPath);
  const force = forceFlag === "true";
  const manifest = loadManifest();

  const sameSchema = manifest.datasets
    .filter((d) => d.schemaVersion === info.schemaVersion)
    .sort((a, b) => b.dataVersion - a.dataVersion);
  const previous = sameSchema[0];

  checkSchemaConstant(info);
  checkModelHash(info, previous);
  checkThresholds(info, previous, force);

  if (previous && previous.sha256 === info.sha256) {
    console.log("NO_CHANGE");
    process.exit(0);
  }
  if (previous && previous.dataVersion >= info.dataVersion) {
    fail(`dataVersion ${info.dataVersion} is not newer than published ${previous.dataVersion}`);
  }

  const entry: ManifestEntry = {
    schemaVersion: info.schemaVersion,
    dataVersion: info.dataVersion,
    generatedAt: info.generatedAt,
    url: assetURL,
    byteSize: info.byteSize,
    sha256: info.sha256,
    modelHash: info.modelHash,
    counts: info.counts,
    changes,
  };
  if (minBuildFlag) entry.minimumAppBuild = Number(minBuildFlag);

  const others = manifest.datasets.filter((d) => d.schemaVersion !== info.schemaVersion);
  const kept = [entry, ...sameSchema].slice(0, HISTORY_PER_SCHEMA);

  const next: Manifest = {
    manifestVersion: MANIFEST_VERSION,
    updatedAt: new Date().toISOString(),
    datasets: [...kept, ...others].sort(
      (a, b) => b.schemaVersion - a.schemaVersion || b.dataVersion - a.dataVersion,
    ),
  };

  writeFileSync(MANIFEST_PATH, JSON.stringify(next, null, 2) + "\n");
  console.log("PUBLISH");
}

main();
