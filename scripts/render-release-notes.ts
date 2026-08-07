#!/usr/bin/env bun
import { readFileSync, writeFileSync } from "node:fs";
import { renderReleaseNotes } from "../data-builder/src/changes";
import type { DatasetChanges } from "../data-builder/src/types";

function main(): void {
  const [, , changesPath, outputPath] = process.argv;
  if (!changesPath || !outputPath) {
    console.error("usage: render-release-notes.ts <metropolist-changes.json> <output.md>");
    process.exit(2);
  }

  const changes = JSON.parse(readFileSync(changesPath, "utf8")) as DatasetChanges;
  const notes = renderReleaseNotes(changes);
  if (notes.trim().length === 0) {
    console.error("renderReleaseNotes produced no output");
    process.exit(1);
  }

  writeFileSync(outputPath, notes.endsWith("\n") ? notes : notes + "\n");
  console.log(`Wrote ${outputPath} (${notes.length} bytes)`);
}

main();
