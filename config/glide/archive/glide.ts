// Default 2 (auto) only picks the portal when sandboxed; 1 forces it, so uploads get the portal picker.
glide.prefs.set("widget.use-xdg-desktop-portal.file-picker", 1);

// The extensions button cannot leave the toolbar; this hides it until an extension needs attention.
glide.prefs.set("extensions.unifiedExtensions.button.always_visible", false);

glide.o.hint_size = "16px";

glide.prefs.set("toolkit.scrollbox.verticalScrollDistance", 3);

// The browser UI's look lives in glide.css; :config_reload reads it again.
glide.fs.read("glide.css", "utf8").then((sheet) => glide.styles.add(sheet));

// Ctrl+N/P move down/up as in vim instead of opening a window and printing; the URL bar only does this on macOS.
glide.keymaps.set("normal", "<C-n>", "caret_move down");
glide.keymaps.set("normal", "<C-p>", "caret_move up");
glide.keymaps.set("command", "<C-n>", "commandline_focus_next");
glide.keymaps.set("command", "<C-p>", "commandline_focus_back");

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

async function switch_workspace(id: string) {
  current = id;
  void render_workspaces();
  await browser.sessions.setWindowValue(window_id, WORKSPACE_KEY, id);
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

// The toolbox goes into the sidebar while the sidebar shows, and back above the page when it hides.
function place_toolbox() {
  const toolbox = document.getElementById("navigator-toolbox");
  const tabs = document.getElementById("vertical-tabs");
  const container = document.getElementById("sidebar-container");
  const target = document.getElementById("nav-bar-customization-target");
  const menu = document.getElementById("PanelUI-button");
  if (!toolbox || !tabs || !container || !target) return;
  // The menu button sits outside the row the buttons wrap in, past the sidebar's edge.
  if (menu && menu.parentElement !== target) target.append(menu);
  const into_sidebar = !container.hasAttribute("hidden");
  if (into_sidebar === (toolbox.parentElement === tabs)) return;
  // A move would blur the URL field, so it waits until the field is left; CSS lays the toolbox out as if moved meanwhile.
  if (document.getElementById("urlbar")?.hasAttribute("focused")) return;
  if (into_sidebar) {
    // sidebar-main cancels right-clicks anywhere in the sidebar but #vertical-tabs; skipintoolbarset keeps CustomizableUI off it there.
    toolbox.setAttribute("skipintoolbarset", "true");
    tabs.prepend(toolbox);
  } else {
    document.getElementById("browser")?.before(toolbox);
  }
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
    const button = DOM.create_element("button", {
      className: "glide-workspace",
      title: w.name,
    });
    if (w.id === current) button.setAttribute("current", "");
    if (w.color) button.style.setProperty("--glide-workspace-color", w.color);
    button.addEventListener("click", () => void switch_workspace(w.id));
    return button;
  });
  const add = DOM.create_element("button", { id: "glide-workspace-new", className: "glide-workspace", title: "New workspace" });
  add.addEventListener("click", () => void pick_workspace());
  const list = DOM.create_element("div", { id: "glide-workspace-list", children: [...buttons, add] });
  const mode = DOM.create_element("span", { id: "glide-mode", children: glide.ctx.mode });
  bar.replaceChildren(list, mode);
}

glide.autocmds.create("ModeChanged", "*", ({ new_mode }) => {
  const mode = document.getElementById("glide-mode");
  if (mode) mode.textContent = new_mode;
});

async function pick_workspace() {
  const spaces = await list_workspaces();
  const taken = (input: string) => spaces.some((w) => w.name.toLowerCase() === input.trim().toLowerCase());
  await glide.commandline.show({
    title: "workspaces",
    options: [
      ...spaces.map((w) => ({
        label: w.name,
        description: w.id === current ? "current" : "",
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

glide.autocmds.create("ConfigLoaded", async () => {
  place_toolbox();
  const observer = new MutationObserver(place_toolbox);
  for (const id of ["sidebar-container", "urlbar"]) {
    const el = document.getElementById(id);
    if (el) observer.observe(el, { attributeFilter: ["hidden", "focused"] });
  }

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
glide.keymaps.set(["normal", "insert"], "<C-j>", () => cycle_tab(1), { description: "Next tab in this workspace" });
glide.keymaps.set(["normal", "insert"], "<C-k>", () => cycle_tab(-1), { description: "Previous tab in this workspace" });
