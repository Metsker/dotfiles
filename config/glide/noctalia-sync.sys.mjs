// ==UserScript==
// @name           noctalia
// @description    Loads the palette noctalia renders for glide and reloads it whenever noctalia rewrites it
// ==/UserScript==

import { setInterval } from "resource://gre/modules/Timer.sys.mjs";

// Rendered from config/noctalia/templates/glide.css on every palette or dark/light change.
const path = PathUtils.join(
  Services.env.get("XDG_CONFIG_HOME") || PathUtils.join(Services.dirsvc.get("Home", Ci.nsIFile).path, ".config"),
  "glide",
  "noctalia.css",
);
const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);

let sheet = null;
let stamp = null;
let busy = false;

async function sync() {
  if (busy) return;
  busy = true;
  try {
    const info = await IOUtils.stat(path).catch(() => null);
    const next = info?.lastModified ?? null;
    if (next === stamp) return;
    stamp = next;
    if (sheet) sss.unregisterSheet(sheet, sss.USER_SHEET);
    sheet = null;
    if (!info) return;
    // A data: URI also reaches content processes, whose sandbox cannot read the file.
    const css = await IOUtils.readUTF8(path);
    sheet = Services.io.newURI("data:text/css;charset=utf-8," + encodeURIComponent(css));
    sss.loadAndRegisterSheet(sheet, sss.USER_SHEET);
  } catch (e) {
    console.error("noctalia: cannot load", path, e);
  } finally {
    busy = false;
  }
}

sync();
// No file watcher reaches privileged JS, so a cheap mtime poll catches noctalia's rewrites.
setInterval(sync, 2000);
