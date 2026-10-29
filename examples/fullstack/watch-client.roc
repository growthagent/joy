#!/usr/bin/env roc
# Build the client once (see build.roc), then hand the loop to
# `roc build --watch`, which rebuilds client/www/app.wasm whenever the client,
# the shared package, or Joy itself changes. Run it in one terminal and
# ./watch-server.roc in another, then refresh the browser after each
# rebuild.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
}

import Script exposing [run!]

main! = |_args| {
	# WORKAROUND: roc-lang/roc#12693 and #12701. A shared roc cache can crash
	# this compile. Drop `--no-cache` when fixed.
	run!("roc", ["--no-cache", "./build.roc"])?
	run!("roc", ["build", "--target=wasm32", "--watch", "--output=client/www/app.wasm", "client/main.roc"])
}
