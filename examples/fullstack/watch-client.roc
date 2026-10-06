#!/usr/bin/env roc
# Build the client once (see build.roc), then hand the loop to
# `roc build --watch`, which rebuilds client/www/app.wasm whenever the client,
# the shared package, or Joy itself changes. Run it in one terminal and
# ./watch-server.roc in another, then refresh the browser after each
# rebuild.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
}

import Util exposing [run!]

main! = |_args| {
	run!("roc", ["./build.roc"])?
	run!("roc", ["build", "--target=wasm32", "--watch", "--output=client/www/app.wasm", "client/main.roc"])
}
