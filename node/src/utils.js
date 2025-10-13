export function parsePositiveInt(value, fallback) {
  if (value === undefined || value === null) {
    return fallback;
  }

  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed <= 0) {
    throw new Error(`Expected a positive integer but received "${value}"`);
  }

  return parsed;
}

export function buildArtRequestPayload(names) {
  if (!Array.isArray(names)) {
    throw new Error("names must be an array");
  }

  const cleaned = names
    .map((name) => (typeof name === "string" ? name.trim() : ""))
    .filter((name) => Boolean(name));

  if (cleaned.length === 0) {
    throw new Error("names cannot be empty");
  }

  return { names: cleaned };
}
