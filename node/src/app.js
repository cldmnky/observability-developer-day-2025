import React, { useCallback, useEffect, useRef, useState } from "react";
import { Box, Text, Spacer, useApp, useInput } from "ink";
import { fetchFiglet, fetchNames } from "./api.js";
import { buildArtRequestPayload } from "./utils.js";

const STATUS = {
  IDLE: "idle",
  LOADING: "loading",
  READY: "ready",
  ERROR: "error"
};

export default function App({ count, seed, apiBase }) {
  const { exit } = useApp();
  const [status, setStatus] = useState(STATUS.IDLE);
  const [error, setError] = useState(null);
  const [art, setArt] = useState([]);
  const [currentSeed, setCurrentSeed] = useState(() => seed ?? null);
  const currentSeedRef = useRef(currentSeed);

  useEffect(() => {
    currentSeedRef.current = currentSeed;
  }, [currentSeed]);

  const fetchAndRender = useCallback(
    async (seedValue) => {
      try {
        setStatus(STATUS.LOADING);
        setError(null);

        const effectiveSeed = seedValue ?? currentSeedRef.current ?? null;

        const names = await fetchNames({ apiBase, count, seed: effectiveSeed });
        const payload = buildArtRequestPayload(names);
        const result = await fetchFiglet({ apiBase, names: payload.names });

        setArt(result);
        setStatus(STATUS.READY);
        setCurrentSeed(effectiveSeed);
      } catch (err) {
        setStatus(STATUS.ERROR);
        setError(err instanceof Error ? err : new Error(String(err)));
      }
    },
    [apiBase, count]
  );

  useEffect(() => {
    fetchAndRender(seed ?? currentSeedRef.current ?? null);
  }, [fetchAndRender, seed]);

  useInput((input, key) => {
    if (input?.toLowerCase() === "q" || key.escape) {
      exit();
    }

    if (input?.toLowerCase() === "r") {
      fetchAndRender(currentSeedRef.current);
    }

    if (input?.toLowerCase() === "n") {
      const newSeed = Date.now().toString();
      fetchAndRender(newSeed);
    }
  });

  const header = `Go ASCII Nameboard — count=${count}${
    currentSeed ? ` seed=${currentSeed}` : ""
  } (r: refresh, n: new seed, q: quit)`;

  const children = [
    React.createElement(Text, { color: "cyanBright", key: "header" }, header),
    React.createElement(Spacer, { key: "spacer" })
  ];

  if (status === STATUS.LOADING) {
    children.push(React.createElement(Text, { key: "loading" }, "Loading…"));
  }

  if (status === STATUS.ERROR) {
    const message = error?.message ?? "unknown error";
    children.push(
      React.createElement(
        Text,
        { color: "red", key: "error" },
        `Error: ${message}`
      )
    );
  }

  if (status === STATUS.READY) {
    const artElements = art.map((entry) =>
      React.createElement(
        Box,
        {
          key: entry.name,
          flexDirection: "column",
          marginBottom: 1
        },
        React.createElement(
          Text,
          { color: "greenBright" },
          entry.name
        ),
        React.createElement(Text, null, entry.figure)
      )
    );

    children.push(
      React.createElement(
        Box,
        { key: "art", flexDirection: "column", marginTop: 1 },
        ...artElements
      )
    );
  }

  return React.createElement(Box, { flexDirection: "column" }, ...children);
}
