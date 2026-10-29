#!/usr/bin/env roc
# The whole dev loop in one command: build the client, keep rebuilding it
# on change in the background, and run the server with hot reload in the
# foreground. Ctrl-C stops everything. Run it from this directory.
#
# Prefer separate terminals? ./watch-client.roc and ./watch-server.roc are
# the same two halves.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
}

import pf.Cmd
import pf.OsStr
import Script exposing [run!]

main! = |_args| {
	# WORKAROUND: roc-lang/roc#12693 and #12701. A shared roc cache can crash
	# this compile. Drop `--no-cache` when fixed.
	run!("roc", ["--no-cache", "./build.roc"])?

	# Leashed, so the watcher dies with this script. The handle is held until
	# the server stops, because releasing it kills the child.
	watcher = Cmd.new(OsStr.from_str("roc"))
		.args(["build", "--target=wasm32", "--watch", "--output=client/www/app.wasm", "client/main.roc"].map(OsStr.from_str))
		.spawn_leashed!() ? |err| WatcherSpawnFailed(err)

	served = run!("roc", ["--watch", "server/main.roc"])
	watcher.close!() ?? {}
	served
}
