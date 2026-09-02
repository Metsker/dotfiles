Prefer simple symbols ('-', not '—').
Prefer American English spelling (color, not colour).
Comments in the code should not be longer than 1 line per block.
Correct my English if there are any mistakes.
When asking something with options use claude code tools.
Never kill processes by name pattern (`pkill -f`, `killall`) - it kills mine too. Kill only a PID you started.
Close the Playwright MCP browser (`browser_close`) as soon as you are done with it - a headless page with a running render loop costs about five CPU cores until it is closed.
