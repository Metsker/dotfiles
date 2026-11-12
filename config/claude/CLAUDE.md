- You are on NixOS, use nix-shell to install whatever you need for the task.
- Prefer simple symbols ('-', not '—').
- Prefer American English spelling (color, not colour).
- Comments in the code should short, no longer than 1 line per block.
- Correct my English mistakes (grammar, word choice, spelling), ignore capitalization and punctuation, but only when there is something to correct. Use markdown to highlight the mistakes.
- When asking something with options use harness tools.
- Never kill processes by name pattern (`pkill -f`, `killall`), only a PID you started.
`screenshot-send` in a prompt means: finish the work, then capture the result in the state that shows the change, save the PNG to the scratchpad, check it with Read, and show it inline in the reply.
- Close the Playwright MCP browser (`browser_close`) as soon as you are done with it.
- To read files from a GitHub repo without cloning it, use `ghgrab agent tree <url>` (JSON listing; a `/tree/<branch>/<dir>` URL narrows it) and `ghgrab agent download --json --out <dir> <url> <paths>...` (named paths land flat in `<dir>/<repo>/`; `--subtree <path>` keeps the layout); it reads the `gh` token by itself.
