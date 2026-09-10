#!/usr/bin/env roc
# The whole dev loop in one command: build the client, keep rebuilding it
# on change in the background, and run the server with hot reload in the
# foreground. Ctrl-C stops everything. Run it from this directory.
#
# Prefer separate terminals? ./watch-client.roc and ./watch-server.roc are
# the same two halves.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.24.0/2mx1EsQx1HEG7HdbW2CwUpexvmJZW4nSCpjbur5GXyRe.tar.zst",
}

import pf.Cmd
import Util exposing [run!]

main! = |_args| {
	run!("roc", ["./build.roc"])?

	# Leashed, so the watcher dies with this script
	_ = Cmd.new_str("roc")
		.args_str(["build", "--target=wasm32", "--watch", "--output=client/www/app.wasm", "client/main.roc"])
		.spawn_leashed!()?

	run!("roc", ["--watch", "server/main.roc"])
}
