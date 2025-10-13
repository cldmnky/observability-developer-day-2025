#!/usr/bin/env node
import React from "react";
import { render } from "ink";
import { Command } from "commander";
import App from "./app.js";
import { parsePositiveInt } from "./utils.js";

const program = new Command();
program
  .name("nameboard")
  .description("Terminal SPA displaying ASCII art names from the Go API")
  .option("-c, --count <number>", "number of names to request", "1")
  .option("-s, --seed <seed>", "seed to make the output deterministic")
  .option(
    "-b, --api-base <url>",
    "base URL for the Go API",
    process.env.GO_NAME_API_BASE || "http://localhost:8080"
  );

program.parse(process.argv);
const options = program.opts();

let count;
try {
  count = parsePositiveInt(options.count, 1);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

const seed = options.seed ?? null;
const apiBase = options.apiBase.replace(/\/$/, "");

render(
  React.createElement(App, {
    count,
    seed,
    apiBase
  })
);
