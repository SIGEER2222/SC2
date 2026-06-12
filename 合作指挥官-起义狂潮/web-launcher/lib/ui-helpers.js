export function escapeHtml(text) {
  return String(text ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function getStatusToneClass(tone) {
  return {
    ok: "status-ok",
    warn: "status-warn",
    error: "status-error",
  }[tone] || "";
}

export function initials(text) {
  const clean = String(text || "").trim();
  if (!clean) return "?";
  const ascii = clean.match(/[A-Za-z0-9]/g);
  if (ascii && ascii.length > 0) return ascii.slice(0, 2).join("").toUpperCase();
  return clean.slice(0, 2);
}

export function getCommanderRace(runtime) {
  const text = String(runtime || "");
  if (text.startsWith("Terran")) return "Terran";
  if (text.startsWith("Protoss")) return "Protoss";
  if (text.startsWith("Zerg")) return "Zerg";
  return "Other";
}

export function getCommanderRaceLabel(race) {
  return {
    Terran: "人族",
    Protoss: "神族",
    Zerg: "虫族",
    Other: "其他",
  }[race] || race;
}

export function renderRowBadgesHtml(badges) {
  return `
      <span class="row-badges">
        ${badges.map((badge) => `<em class="${badge.className || ""}">${escapeHtml(badge.text)}</em>`).join("")}
      </span>
    `;
}

export function setElementDetail(element, lines) {
  const text = lines.filter(Boolean).join("\n");
  element.title = text;
  element.setAttribute("aria-label", text);
}
