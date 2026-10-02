#!/usr/bin/env roc
# Run the server with hot reload: `roc --watch` rebuilds server/main.roc on
# every change and swaps the new code into the running process, so the
# server keeps its port and its SQLite pool across edits. Run it in one
# terminal and ./watch-client.roc in another (or run both with ./dev.roc).
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.27.0/HZanbveSUDoJF8LypR663eH7PpaKEKG36eErEQzmV1Qs.tar.zst",
}

import pf.Path
import Util exposing [fail!, run!]

main! = |_args| {
	# The server starts fine without a built client, and the page then 404s
	# on app.wasm with nothing saying how to fix it. This does.
	_ = if Path.utf8("client/www/app.wasm").is_file!()? {
		Ok({})
	} else {
		fail!("the client is not built yet: run ./build.roc once, or ./watch-client.roc in another terminal, then start the server")
	}?

	run!("roc", ["--watch", "server/main.roc"])
}
