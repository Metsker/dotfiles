You are on NixOS, use nix-shell to install whatever you need for the task.
Prefer simple symbols ('-', not '—').
Prefer American English spelling (color, not colour).
Comments in the code should not be longer than 1 line per block.
Correct my English if there are any mistakes.
When asking something with options use claude code tools.
Never kill processes by name pattern (`pkill -f`, `killall`) - it kills mine too. Kill only a PID you started.
`screenshot-send` in a prompt means: finish the work, then capture the result in the state that shows the change, save the PNG to the scratchpad, check it with Read, and show it inline in the reply.
Close the Playwright MCP browser (`browser_close`) as soon as you are done with it - a headless page with a running render loop costs about five CPU cores until it is closed.
