#!/usr/bin/env roc
# The whole dev loop in one command: build the client, keep rebuilding it
# on change in the background, and run the server with hot reload in the
# foreground. Ctrl-C stops everything. Run it from this directory.
#
# Prefer separate terminals? ./watch-client.roc and ./watch-server.roc are
# the same two halves.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
}

import pf.Cmd
import Script exposing [run!]

main! = |_args| {
	run!("roc", ["./build.roc"])?

	# Leashed, so the watcher dies with this script. The handle is held until
	# the server stops, because releasing it kills the child.
	watcher = Cmd.new_str("roc")
		.args_str(["build", "--target=wasm32", "--watch", "--output=client/www/app.wasm", "client/main.roc"])
		.spawn_leashed!() ? |err| WatcherSpawnFailed(err)

	served = run!("roc", ["--watch", "server/main.roc"])
	watcher.close!() ?? {}
	served
}
