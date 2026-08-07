import type {
  DatasetChanges,
  DatasetChangeDelta,
  DatasetHighlight,
  DiffDetail,
  Line,
  Station,
} from "./types";

const MAX_HIGHLIGHTS = 20;
const MAX_LABEL_LENGTH = 60;
const MAX_SUMMARY_LENGTH = 400;

function clamp(value: string, limit: number): string {
  const cleaned = value.replace(/[\p{Cc}\p{Cf}]/gu, " ").trim();
  return cleaned.length <= limit ? cleaned : cleaned.slice(0, limit - 1).trimEnd() + "…";
}

function lineLabel(line: Line): string {
  return clamp(line.shortName || line.longName || line.id, MAX_LABEL_LENGTH);
}

function stationLabel(station: Station): string {
  return clamp(station.name || station.id, MAX_LABEL_LENGTH);
}

function buildDelta(detail: DiffDetail): DatasetChangeDelta {
  return {
    linesAdded: detail.lines.added.length,
    linesRemoved: detail.lines.removed.length,
    linesModified: detail.lines.modified.length,
    stationsAdded: detail.stations.added.length,
    stationsRemoved: detail.stations.removed.length,
    stationsModified: detail.stations.modified.length,
    routeVariantsChanged:
      detail.routeVariants.added.length +
      detail.routeVariants.removed.length +
      detail.routeVariants.modified.length,
    transfersChanged: detail.transfers.added + detail.transfers.removed,
  };
}

function buildHighlights(detail: DiffDetail): DatasetHighlight[] {
  const highlights: DatasetHighlight[] = [];

  for (const line of detail.lines.added) {
    highlights.push({
      kind: "lineAdded",
      label: lineLabel(line),
      detail: line.longName && line.longName !== line.shortName ? clamp(line.longName, MAX_LABEL_LENGTH) : undefined,
    });
  }
  for (const line of detail.lines.removed) {
    highlights.push({ kind: "lineRemoved", label: lineLabel(line) });
  }
  for (const { station, previous } of detail.stations.modified) {
    if (station.name === previous.name) continue;
    highlights.push({
      kind: "stationRenamed",
      label: stationLabel(station),
      detail: clamp(previous.name, MAX_LABEL_LENGTH),
    });
  }
  for (const station of detail.stations.added) {
    highlights.push({
      kind: "stationAdded",
      label: stationLabel(station),
      detail: station.town ? clamp(station.town, MAX_LABEL_LENGTH) : undefined,
    });
  }
  for (const station of detail.stations.removed) {
    highlights.push({ kind: "stationRemoved", label: stationLabel(station) });
  }

  return highlights.slice(0, MAX_HIGHLIGHTS);
}

function plural(count: number, singular: string, pluralForm: string): string {
  return `${count} ${count === 1 ? singular : pluralForm}`;
}

function buildSummary(delta: DatasetChangeDelta): { en: string; fr: string } | undefined {
  const en: string[] = [];
  const fr: string[] = [];

  if (delta.linesAdded > 0) {
    en.push(`${plural(delta.linesAdded, "line", "lines")} added`);
    fr.push(`${delta.linesAdded} ligne${delta.linesAdded > 1 ? "s" : ""} ajoutée${delta.linesAdded > 1 ? "s" : ""}`);
  }
  if (delta.linesRemoved > 0) {
    en.push(`${plural(delta.linesRemoved, "line", "lines")} removed`);
    fr.push(`${delta.linesRemoved} ligne${delta.linesRemoved > 1 ? "s" : ""} supprimée${delta.linesRemoved > 1 ? "s" : ""}`);
  }
  if (delta.stationsAdded > 0) {
    en.push(`${plural(delta.stationsAdded, "stop", "stops")} added`);
    fr.push(`${delta.stationsAdded} arrêt${delta.stationsAdded > 1 ? "s" : ""} ajouté${delta.stationsAdded > 1 ? "s" : ""}`);
  }
  if (delta.stationsRemoved > 0) {
    en.push(`${plural(delta.stationsRemoved, "stop", "stops")} removed`);
    fr.push(`${delta.stationsRemoved} arrêt${delta.stationsRemoved > 1 ? "s" : ""} supprimé${delta.stationsRemoved > 1 ? "s" : ""}`);
  }
  if (delta.stationsModified > 0) {
    en.push(`${plural(delta.stationsModified, "stop", "stops")} updated`);
    fr.push(`${delta.stationsModified} arrêt${delta.stationsModified > 1 ? "s" : ""} mis à jour`);
  }

  if (en.length === 0) return undefined;
  return {
    en: clamp(en.join(", "), MAX_SUMMARY_LENGTH),
    fr: clamp(fr.join(", "), MAX_SUMMARY_LENGTH),
  };
}

export function buildDiffSummary(detail: DiffDetail): DatasetChanges {
  const delta = buildDelta(detail);
  return {
    delta,
    highlights: buildHighlights(detail),
    summary: buildSummary(delta),
  };
}

export function isEmptyChange(changes: DatasetChanges): boolean {
  return Object.values(changes.delta).every((value) => value === 0);
}

export function renderReleaseNotes(changes: DatasetChanges): string {
  const lines: string[] = ["### Data Update", ""];

  if (changes.summary) {
    lines.push(changes.summary.en, "");
  }

  const d = changes.delta;
  const rows: [string, number][] = [
    ["Lines added", d.linesAdded],
    ["Lines removed", d.linesRemoved],
    ["Lines updated", d.linesModified],
    ["Stops added", d.stationsAdded],
    ["Stops removed", d.stationsRemoved],
    ["Stops updated", d.stationsModified],
    ["Routes changed", d.routeVariantsChanged],
    ["Transfers changed", d.transfersChanged],
  ];
  const present = rows.filter(([, value]) => value > 0);
  if (present.length > 0) {
    lines.push("| Change | Count |", "| --- | --- |");
    for (const [label, value] of present) lines.push(`| ${label} | ${value} |`);
    lines.push("");
  }

  if (changes.highlights.length > 0) {
    lines.push("**Highlights**", "");
    for (const h of changes.highlights) {
      const suffix = h.detail ? ` — ${h.detail}` : "";
      lines.push(`- \`${h.kind}\` ${h.label}${suffix}`);
    }
    lines.push("");
  }

  if (present.length === 0 && changes.highlights.length === 0) {
    lines.push("No data changes.", "");
  }

  return lines.join("\n");
}
