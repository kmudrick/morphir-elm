const { readFile } = require("fs/promises");

// Based on example from https://github.com/mpizenberg/elm-solve-deps-wasm/example-online
const solve = async (
  elmConfigPath,
  useTest = false,
  additionalConstraints = {}
) => {
  // Requiring this module automatically starts up workers which
  // must be shut down or the process will hang
  const { solveOnline, shutDown } = await require("./DependencyProvider.js");
  try {
    const elmJsonConfig = await readFile(elmConfigPath, "utf8");
    return solveOnline(elmJsonConfig, useTest, additionalConstraints);
  } finally {
    shutDown();
  }
};

module.exports = solve;
