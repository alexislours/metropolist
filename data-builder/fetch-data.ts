#!/usr/bin/env bun
/**
 * Fetch latest IDFM transit data.
 *
 * Downloads GTFS + 3 JSON datasets from open data APIs,
 * after backing up existing data to a dated subfolder.
 *
 * Usage:  bun run fetch-data.ts
 */

import { log } from "./src/helpers";
import { cp, mkdir, rm } from "node:fs/promises";
import JSZip from "jszip";

const DATA = "./data";
const GTFS_DIR = `${DATA}/IDFM-gtfs`;
const BACKUP = `${DATA}/backup`;

const SOURCES = {
  gtfs: "https://www.data.gouv.fr/api/1/datasets/r/f9fff5b1-f9e4-4ec2-b8b3-8ad7005d869c",
  referentielDesLignes:
    "https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/referentiel-des-lignes/exports/json",
  arrets:
    "https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/arrets/exports/json",
  arretsLignes:
    "https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/arrets-lignes/exports/json",
};

const JSON_FILES = [
  "referentiel-des-lignes.json",
  "arrets.json",
  "arrets-lignes.json",
] as const;

async function backup() {
  const now = new Date();
  const stamp = now.toISOString().slice(0, 19).replace(/[:T]/g, (c) => (c === "T" ? "_" : ""));
  const dest = `${BACKUP}/${stamp}`;

  log(`Backing up data to ${dest}/`);
  await mkdir(dest, { recursive: true });

  for (const name of JSON_FILES) {
    const src = `${DATA}/${name}`;
    if (await Bun.file(src).exists()) {
      await Bun.write(`${dest}/${name}`, Bun.file(src));
      log(`  ${name}`);
    }
  }

  if (await Bun.file(`${GTFS_DIR}/stops.txt`).exists()) {
    await cp(GTFS_DIR, `${dest}/IDFM-gtfs`, { recursive: true });
    log(`  IDFM-gtfs/`);
  }
}

const SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

type TaskState = { status: "active"; detail: string } | { status: "done"; detail: string };

const progress = {
  tasks: new Map<string, TaskState>(),
  frame: 0,
  interval: null as ReturnType<typeof setInterval> | null,
  rendered: false,

  register(label: string) {
    this.tasks.set(label, { status: "active", detail: "waiting" });
    if (!this.interval) {
      this.interval = setInterval(() => this.render(), 80);
    }
  },

  update(label: string, detail: string) {
    this.tasks.set(label, { status: "active", detail });
  },

  finish(label: string, detail: string) {
    this.tasks.set(label, { status: "done", detail });
    const allDone = [...this.tasks.values()].every((t) => t.status === "done");
    if (allDone && this.interval) {
      clearInterval(this.interval);
      this.interval = null;
      this.render();
      process.stdout.write("\n");
    }
  },

  render() {
    this.frame = (this.frame + 1) % SPINNER.length;

    if (this.rendered) {
      process.stdout.write(`\x1b[${this.tasks.size}A`);
    }

    for (const [label, state] of this.tasks) {
      const icon = state.status === "done" ? "✓" : SPINNER[this.frame];
      process.stdout.write(`\x1b[2K  ${icon} ${label} (${state.detail})\n`);
    }

    this.rendered = true;
  },
};


function formatSize(bytes: number): string {
  if (bytes < 1e6) return `${(bytes / 1e3).toFixed(0)} KB`;
  return `${(bytes / 1e6).toFixed(1)} MB`;
}

async function streamFetch(url: string, label: string): Promise<Uint8Array> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${label}: HTTP ${res.status} ${res.statusText}`);

  const total = Number(res.headers.get("content-length") || 0);
  const chunks: Uint8Array[] = [];
  let received = 0;

  for await (const chunk of res.body!) {
    chunks.push(chunk);
    received += chunk.length;
    const detail = total
      ? `${formatSize(received)} / ${formatSize(total)}`
      : formatSize(received);
    progress.update(label, detail);
  }

  const buf = new Uint8Array(received);
  let offset = 0;
  for (const chunk of chunks) {
    buf.set(chunk, offset);
    offset += chunk.length;
  }
  return buf;
}

async function fetchJson(url: string, dest: string, label: string) {
  const buf = await streamFetch(url, label);
  await Bun.write(dest, buf);
  progress.finish(label, formatSize(buf.byteLength));
}

async function fetchAndExtractGtfs() {
  const label = "GTFS";
  const buf = await streamFetch(SOURCES.gtfs, label);

  progress.update(label, `extracting ${formatSize(buf.byteLength)}`);

  await rm(GTFS_DIR, { recursive: true, force: true });
  await mkdir(GTFS_DIR, { recursive: true });

  const zip = await JSZip.loadAsync(buf);
  const entries = Object.entries(zip.files).filter(([, f]) => !f.dir);

  await Promise.all(
    entries.map(async ([path, file]) => {
      const name = path.includes("/") ? path.split("/").pop()! : path;
      const content = await file.async("uint8array");
      await Bun.write(`${GTFS_DIR}/${name}`, content);
    }),
  );

  progress.finish(label, `${entries.length} files, ${formatSize(buf.byteLength)}`);
}

async function main() {
  const start = performance.now();
  log("Starting data fetch...");

  await backup();

  log("Downloading datasets...");
  progress.register("referentiel-des-lignes");
  progress.register("arrets");
  progress.register("arrets-lignes");
  progress.register("GTFS");
  await Promise.all([
    fetchJson(SOURCES.referentielDesLignes, `${DATA}/referentiel-des-lignes.json`, "referentiel-des-lignes"),
    fetchJson(SOURCES.arrets, `${DATA}/arrets.json`, "arrets"),
    fetchJson(SOURCES.arretsLignes, `${DATA}/arrets-lignes.json`, "arrets-lignes"),
    fetchAndExtractGtfs(),
  ]);

  const elapsed = ((performance.now() - start) / 1000).toFixed(1);
  log(`Done in ${elapsed}s`);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
