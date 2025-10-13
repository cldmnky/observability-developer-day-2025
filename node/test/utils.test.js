import assert from "node:assert/strict";
import test from "node:test";
import { buildArtRequestPayload, parsePositiveInt } from "../src/utils.js";

test("parsePositiveInt returns fallback when value undefined", () => {
  assert.equal(parsePositiveInt(undefined, 3), 3);
});

test("parsePositiveInt throws on invalid input", () => {
  assert.throws(() => parsePositiveInt("zero", 1));
  assert.throws(() => parsePositiveInt("0", 1));
});

test("buildArtRequestPayload trims and filters names", () => {
  const result = buildArtRequestPayload([" Agile Albatross ", "", null, "Bold Badger"]);
  assert.deepEqual(result, { names: ["Agile Albatross", "Bold Badger"] });
});

test("buildArtRequestPayload throws on empty result", () => {
  assert.throws(() => buildArtRequestPayload(["  ", null]));
});
