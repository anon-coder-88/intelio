import test from "node:test";
import assert from "node:assert/strict";
import { toWei } from "../src/index.js";

test("base units preserve zero, exact wei and ETH", () => {
  assert.equal(toWei("0"), 0n);
  assert.equal(toWei("0.000000000000000001"), 1n);
  assert.equal(toWei("1.25"), 1250000000000000000n);
});
test("rejects signed, nonfinite, exponent, blank and rounding inputs", () => {
  for (const invalid of [
    "-1",
    "+1",
    "NaN",
    "Infinity",
    "1e3",
    "",
    " 1 ",
    "01",
    "0.0000000000000000001",
  ]) {
    assert.throws(() => toWei(invalid));
  }
});
