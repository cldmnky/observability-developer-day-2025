export async function fetchNames({ apiBase, count, seed }) {
  const params = new URLSearchParams();
  if (count && count > 0) {
    params.set("count", String(count));
  }
  if (seed) {
    params.set("seed", seed);
  }

  const response = await fetch(`${apiBase}/api/name?${params.toString()}`);
  if (!response.ok) {
    const message = await safeReadError(response);
    throw new Error(`Failed to fetch names (${response.status}): ${message}`);
  }

  const { names } = await response.json();
  return names.map((entry) => entry.combined);
}

export async function fetchFiglet({ apiBase, names }) {
  const response = await fetch(`${apiBase}/api/figlet`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ names })
  });

  if (!response.ok) {
    const message = await safeReadError(response);
    throw new Error(`Failed to render figlet art (${response.status}): ${message}`);
  }

  const { art } = await response.json();
  return art;
}

async function safeReadError(response) {
  try {
    const body = await response.text();
    return body || response.statusText;
  } catch (error) {
    return response.statusText;
  }
}
