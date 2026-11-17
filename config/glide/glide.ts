// Default 2 (auto) only picks the portal when sandboxed; 1 forces it, so uploads get the portal picker.
glide.prefs.set("widget.use-xdg-desktop-portal.file-picker", 1);

// The extensions button cannot leave the toolbar; this hides it until an extension needs attention.
glide.prefs.set("extensions.unifiedExtensions.button.always_visible", false);

glide.o.hint_size = "16px";

glide.prefs.set("toolkit.scrollbox.verticalScrollDistance", 3);

// New tabs go to the bottom of the list; tabs opened from a link still land next to their parent.
glide.prefs.set("browser.tabs.insertAfterCurrent", false);

// The workspace row already shows the container, so the URL bar and tabs drop theirs; zoom becomes an accent pill.
glide.styles.add(`
  /* Glide skips a hint whose box center is covered, which a long title's center past the sidebar edge is. */
  .tab-label {
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  /* Natsumi greys the selected result but keeps Firefox's SelectedItemText, the GTK accent's dark text; its Nova patch does this too. */
  .urlbarView-row {
    --urlbarview-text-color-selected: currentColor !important;
  }
  #userContext-icons,
  .tab-context-line {
    display: none !important;
  }
  /* Natsumi's user sheet paints every splitter in the accent on hover; opacity keeps the pinned-tabs one draggable but unseen. */
  #vertical-pinned-tabs-splitter {
    display: none !important;
  }
  /* Natsumi pins toolbar buttons' height and inline padding from a user sheet, so the pill is drawn on the label inside. */
  #urlbar-zoom-button {
    margin: 0 4px !important;
    background: none !important;
    color: var(--natsumi-primary-color, currentColor) !important;
    font-size: 0.8em !important;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    overflow: visible !important;
    > .toolbarbutton-text {
      padding: 2px 8px;
      border-radius: 999px;
      background-color: color-mix(in srgb, var(--natsumi-primary-color, currentColor) 18%, transparent);
    }
    &:hover > .toolbarbutton-text {
      background-color: color-mix(in srgb, var(--natsumi-primary-color, currentColor) 30%, transparent);
    }
  }
`);

// The workspace row below the tabs is the sidebar's footer instead of Natsumi's bottom toolbar.
glide.prefs.set("natsumi.sidebar.disable-bottom-toolbar", true);

// Ctrl+N/P move down/up as in vim instead of opening a window and printing.
glide.keymaps.set("normal", "<C-n>", "caret_move down");
glide.keymaps.set("normal", "<C-p>", "caret_move up");
glide.keymaps.set("command", "<C-n>", "commandline_focus_next");
glide.keymaps.set("command", "<C-p>", "commandline_focus_back");
// Firefox walks URL bar results with Ctrl+N/P only on macOS, so the URL bar gets Down/Up; other fields keep the keys' usual meaning.
for (const [lhs, key] of [["<C-n>", "<Down>"], ["<C-p>", "<Up>"]] as const) {
  glide.keymaps.set("insert", lhs, () => {
    const in_urlbar = document.getElementById("urlbar")?.hasAttribute("focused");
    return glide.keys.send(in_urlbar ? key : lhs, { skip_mappings: true });
  });
}

// Esc leaves a text field instead of starting vim editing in it; blurring drops back to normal mode.
glide.keymaps.set("insert", "<Esc>", "blur");
glide.keymaps.set("insert", "<C-[>", "blur");

// Glide hints a tab through its label, which a pinned tab hides, so the tab itself joins the hints.
glide.keymaps.set(
  "normal",
  "<leader>f",
  () => glide.hints.show({ location: "browser-ui", include: ".tabbrowser-tab[pinned]" }),
  { description: "Hint the browser UI, pinned tabs included" },
);

// Workspaces: one per container plus "Default" for tabs outside any; a window shows one and hides the rest.
glide.prefs.set("privacy.userContext.enabled", true);
glide.prefs.set("privacy.userContext.ui.enabled", true);

const NO_CONTAINER = "firefox-default";
const WORKSPACE_KEY = "workspace";
const COLORS = ["blue", "turquoise", "green", "yellow", "orange", "red", "pink", "purple"];

type Workspace = { id: string; name: string; color?: string };

let window_id = -1;
let current = NO_CONTAINER;
// Tabs opened outside a container, waiting for their URL to be reopened in the current workspace.
const pending = new Set<number>();

async function list_workspaces(): Promise<Workspace[]> {
  const containers = await browser.contextualIdentities.query({});
  return [
    { id: NO_CONTAINER, name: "Default" },
    ...containers.map((c) => ({ id: c.cookieStoreId, name: c.name, color: c.colorCode })),
  ];
}

// The config runs once per window and no API names that window, so mark its title and look it up.
async function find_own_window(): Promise<number> {
  const title = document.title;
  const marker = `glide-workspaces-${Math.random()}`;
  document.title = marker;
  try {
    const win = (await browser.windows.getAll()).find((w) => w.title === marker);
    if (win?.id === undefined) throw new Error("workspaces: cannot find this window");
    return win.id;
  } finally {
    document.title = title;
  }
}

const SWITCH_OUT_MS = 100;
const SWITCH_IN_MS = 180;
const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

let switching = Promise.resolve();
let latest = 0;
// The newest requested workspace; the row highlights it at once and cycling steps on from it.
let queued = NO_CONTAINER;
// Net cycling steps away from `current`, so a burst that wraps still slides the way the keys point.
let drift = 0;

// Only the newest request runs: older queued ones are dropped and a running one stops before touching tabs.
function switch_workspace(id: string, step?: number): Promise<void> {
  const request = ++latest;
  queued = id;
  if (step === undefined) drift = 0;
  void render_workspaces();
  switching = switching
    .then(() => (request === latest ? swap_workspace(id, step, request) : undefined))
    .catch((e) => console.error(e));
  return switching;
}

// tabs.show/hide/update each repaint the list, so it slides out first and the swap happens unseen, as Zen slides its spaces.
async function swap_workspace(id: string, hint: number | undefined, request: number) {
  const strip = document.getElementById("tabbrowser-arrowscrollbox");
  // A cancelled switch leaves the list slid out for the one that replaced it.
  const left = strip?.getAttribute("glide-switch") ?? "";
  const faded = left.startsWith("out-");
  const ids = (await list_workspaces()).map((w) => w.id);
  const step = id === current ? 0 : hint || ids.indexOf(id) - ids.indexOf(current);
  const direction = step > 0 || (!step && left.endsWith("-prev")) ? "next" : "prev";

  if (strip && step && !faded) {
    strip.setAttribute("glide-switch", `out-${direction}`);
    await sleep(SWITCH_OUT_MS);
    if (request !== latest) return;
  }
  current = id;
  drift = 0;

  const tabs = await browser.tabs.query({ windowId: window_id, pinned: false });
  const members = tabs.filter((t) => t.cookieStoreId === id);
  if (members.length) await browser.tabs.show(members.map((t) => t.id!));
  if (!members.some((t) => t.active)) {
    const last = members.reduce<Browser.Tabs.Tab | undefined>(
      (a, b) => (!a || (b.lastAccessed ?? 0) > (a.lastAccessed ?? 0) ? b : a),
      undefined,
    );
    if (last) await browser.tabs.update(last.id!, { active: true });
    else await browser.tabs.create({ windowId: window_id, cookieStoreId: id });
  }
  const others = tabs.filter((t) => t.cookieStoreId !== id).map((t) => t.id!);
  if (others.length) await browser.tabs.hide(others);
  await browser.sessions.setWindowValue(window_id, WORKSPACE_KEY, id);

  // A newer request arrived mid-swap; it slides the list back in once its own tabs are up.
  if (request !== latest || !strip || !(step || faded)) return;
  strip.setAttribute("glide-switch", `in-${direction}`);
  setTimeout(() => request === latest && strip.removeAttribute("glide-switch"), SWITCH_IN_MS + 50);
}

async function create_workspace(name: string) {
  // Firefox reports turquoise as "cyan".
  const containers = await browser.contextualIdentities.query({});
  const used = new Set(containers.map((c) => (c.color === "cyan" ? "turquoise" : c.color)));
  const color = COLORS.find((c) => !used.has(c)) ?? COLORS[used.size % COLORS.length]!;
  const container = await browser.contextualIdentities.create({ name, color, icon: "circle" });
  await switch_workspace(container.cookieStoreId);
}

// A tab cannot change container, so the page reopens there unloaded and the old tab closes.
async function move_tab(tab: Browser.Tabs.Tab, id: string) {
  await browser.tabs.create({
    windowId: window_id,
    cookieStoreId: id,
    url: tab.url,
    title: tab.title,
    index: tab.index + 1,
    active: false,
    discarded: true,
  });
  await browser.tabs.remove(tab.id!);
}

async function pick_workspace() {
  const spaces = await list_workspaces();
  const taken = (input: string) => spaces.some((w) => w.name.toLowerCase() === input.trim().toLowerCase());
  await glide.commandline.show({
    title: "workspaces",
    options: [
      ...spaces.map((w) => ({
        label: w.name,
        description: w.id === queued ? "current" : "",
        execute: () => void switch_workspace(w.id),
      })),
      {
        label: "new workspace",
        description: "named after the input",
        matches: ({ input }) => input.trim() !== "" && !taken(input),
        execute: ({ input }) => void create_workspace(input.trim()),
      },
    ],
  });
}

// One button per workspace under the tabs, named only in its tooltip; "+" opens the workspace picker.
async function render_workspaces() {
  const tabs = document.getElementById("vertical-tabs");
  if (!tabs) return;
  let bar = document.getElementById("glide-workspaces");
  if (!bar) {
    bar = DOM.create_element("div", { id: "glide-workspaces" });
    tabs.append(bar);
  }
  const buttons = (await list_workspaces()).map((w) => {
    const button = DOM.create_element("button", { className: "glide-workspace", title: w.name });
    if (w.id === queued) button.setAttribute("current", "");
    if (w.color) button.style.setProperty("--glide-workspace-color", w.color);
    button.addEventListener("click", () => void switch_workspace(w.id));
    return button;
  });
  const add = DOM.create_element("button", { id: "glide-workspace-new", className: "glide-workspace", title: "New workspace" });
  add.addEventListener("click", () => void pick_workspace());
  bar.replaceChildren(...buttons, add);
}

glide.styles.add(`
  /* Tabs fill the sidebar so Firefox's tools row falls past its clip; Natsumi's hide-sidebar-controls skips windows with natsumi-append-installed. */
  #vertical-tabs {
    min-height: 100% !important;
  }
  /* The unpinned tabs leave toward the previous workspace's side and enter from the next one's. */
  #tabbrowser-arrowscrollbox {
    --glide-switch-shift: 12px;
    &[glide-switch$="-prev"] {
      --glide-switch-shift: -12px;
    }
    &[glide-switch^="out-"] {
      animation: glide-switch-out ${SWITCH_OUT_MS}ms ease-in forwards;
    }
    &[glide-switch^="in-"] {
      animation: glide-switch-in ${SWITCH_IN_MS}ms cubic-bezier(0.2, 0, 0, 1);
    }
  }
  @keyframes glide-switch-out {
    to {
      opacity: 0;
      translate: calc(-1 * var(--glide-switch-shift)) 0;
    }
  }
  @keyframes glide-switch-in {
    from {
      opacity: 0;
      translate: var(--glide-switch-shift) 0;
    }
  }
  #glide-workspaces {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    align-items: center;
    gap: 3px;
    padding: 4px var(--tab-margin-inline-inner, 4px);
    sidebar-main:not([expanded]) & {
      flex-direction: column;
    }
  }
  .glide-workspace {
    display: flex;
    align-items: center;
    padding: 7px;
    border: none;
    border-radius: var(--tab-border-radius, 6px);
    background: none;
    color: inherit;
    font: inherit;
    &:hover {
      background-color: color-mix(in srgb, currentColor 12%, transparent);
    }
    &::before {
      content: "";
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background-color: var(--glide-workspace-color, currentColor);
      opacity: 0.5;
    }
    &[current] {
      background-color: color-mix(in srgb, var(--glide-workspace-color, currentColor) 18%, transparent);
      &::before {
        opacity: 1;
      }
    }
  }
  #glide-workspace-new::before {
    content: "+";
    height: auto;
    line-height: 12px;
    font-size: 1.15em;
    text-align: center;
    background: none;
    opacity: 0.7;
  }
`);

glide.autocmds.create("ConfigLoaded", async () => {
  window_id = await find_own_window();
  const saved = await browser.sessions.getWindowValue(window_id, WORKSPACE_KEY);
  const [active] = await browser.tabs.query({ windowId: window_id, active: true });
  const ids = (await list_workspaces()).map((w) => w.id);
  const fallback = active && !active.pinned ? active.cookieStoreId! : NO_CONTAINER;
  current = typeof saved === "string" && ids.includes(saved) ? saved : fallback;

  browser.tabs.onCreated.addListener((tab) => {
    if (tab.windowId !== window_id || tab.pinned || tab.cookieStoreId === current) return;
    if (tab.cookieStoreId === NO_CONTAINER && !tab.discarded) pending.add(tab.id!);
    else if (!tab.active) browser.tabs.hide(tab.id!);
  });

  browser.tabs.onUpdated.addListener(
    async (tab_id, change, tab) => {
      if (!change.url || !pending.delete(tab_id) || tab.cookieStoreId === current) return;
      const blank = ["about:blank", "about:newtab", "about:home"].includes(change.url);
      await browser.tabs.create({
        windowId: window_id,
        cookieStoreId: current,
        url: blank ? undefined : change.url,
        index: tab.index,
        active: tab.active,
      });
      await browser.tabs.remove(tab_id);
    },
    { properties: ["url"] },
  );

  // Reaching another workspace's tab, from a tab list or a session restore, switches to that workspace.
  browser.tabs.onActivated.addListener(async ({ tabId, windowId }) => {
    if (windowId !== window_id || pending.has(tabId)) return;
    const tab = await browser.tabs.get(tabId);
    if (!tab.pinned && tab.cookieStoreId !== current) await switch_workspace(tab.cookieStoreId!);
  });

  for (const event of ["onCreated", "onRemoved", "onUpdated"] as const) {
    browser.contextualIdentities[event].addListener(() => void render_workspaces());
  }

  await switch_workspace(current);
});

glide.keymaps.set("normal", "<leader>w", pick_workspace, { description: "Switch to or create a workspace" });

glide.keymaps.set(
  "normal",
  "<leader>W",
  async ({ tab_id }) => {
    const tab = await browser.tabs.get(tab_id);
    const spaces = (await list_workspaces()).filter((w) => w.id !== tab.cookieStoreId);
    await glide.commandline.show({
      title: "move tab to workspace",
      options: spaces.map((w) => ({ label: w.name, execute: () => void move_tab(tab, w.id) })),
    });
  },
  { description: "Move the current tab to another workspace" },
);

// glide's tab_next/tab_prev walk every tab, so they step into other workspaces' hidden tabs; these wrap within the shown ones.
async function cycle_tab(step: number) {
  const tabs = await browser.tabs.query({ windowId: window_id, hidden: false });
  const i = tabs.findIndex((t) => t.active);
  const next = tabs[(i + step + tabs.length) % tabs.length];
  if (next && !next.active) await browser.tabs.update(next.id!, { active: true });
}
glide.keymaps.set("normal", "J", () => cycle_tab(1), { description: "Next tab in this workspace" });
glide.keymaps.set("normal", "K", () => cycle_tab(-1), { description: "Previous tab in this workspace" });
// Capitals would type in a text field, so insert mode keeps the modifier versions.
glide.keymaps.set("insert", "<C-j>", () => cycle_tab(1), { description: "Next tab in this workspace" });
glide.keymaps.set("insert", "<C-k>", () => cycle_tab(-1), { description: "Previous tab in this workspace" });
glide.keymaps.del("normal", "<C-j>");
glide.keymaps.del("normal", "<C-k>");

glide.keymaps.set("normal", "H", "back");
glide.keymaps.set("normal", "L", "forward");

// Steps through the workspace row and wraps at its ends; the wrap still slides the way the key points.
async function cycle_workspace(step: number) {
  const ids = (await list_workspaces()).map((w) => w.id);
  const i = ids.indexOf(queued);
  drift += step;
  await switch_workspace(ids[(i + step + ids.length) % ids.length]!, drift);
}
glide.keymaps.set(["normal", "insert"], "<A-h>", () => cycle_workspace(-1), { description: "Previous workspace" });
glide.keymaps.set(["normal", "insert"], "<A-l>", () => cycle_workspace(1), { description: "Next workspace" });
