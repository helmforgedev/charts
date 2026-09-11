// SPDX-License-Identifier: Apache-2.0
import fs from "node:fs";
import { createHelper } from "./admission.mjs";
const server = createHelper(fs.readFileSync("/admission-key/key"));
server.listen(8088);
for (const signal of ["SIGTERM", "SIGINT"])
  process.on(signal, () => {
    server.closeAllConnections();
    server.close(() => process.exit(0));
  });
