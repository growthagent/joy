#!/usr/bin/env roc
# One-off build of the client: compile client/main.roc to client/www/app.wasm
# and put Joy's runtime.js next to it, where the server serves the rest of
# client/www/ from. Both are gitignored. Run from this directory.
#
# The server is not built here: `roc server/main.roc` compiles it on start
# (see watch-server.roc).
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
}

import pf.Cmd
import pf.Env
import pf.Path
import pf.Stderr
import Util exposing [fail!]

out_path = "client/www/app.wasm"

main! = |_args| {
	check_wasm_host!()?

	# roc can exit 0 without writing anything, so drop the wasm up front and
	# check that it came back. Something stale mustn't reach the browser.
	drop!(out_path)?

	build_app!()?

	copy_runtime!()
}

# Handle building against a local clone of the Joy repo. Not needed
# if you're using a released version.
check_wasm_host! = || {
	url = platform_url!()?
	if url.starts_with("https://") or url.starts_with("http://") {
		Ok({})
	} else {
		host = "client/${url.drop_suffix("main.roc")}targets/wasm32/host.wasm"
		if Path.utf8(host).is_file!()? {
			Ok({})
		} else {
			fail!("Joy's wasm host is not built (no ${host}). Run ./build.roc --opt=speed at the Joy repo root once, then come back here.")
		}
	}
}

drop! = |file| {
	path = Path.utf8(file)
	if path.is_file!()? {
		path.delete!()
	} else {
		Ok({})
	}
}

# The page's runtime.js is Joy's client runtime, shipped beside the platform
# so it always matches it. A bundle platform (by URL) sits in roc's package
# cache after the build, so the runtime is copied out of there. A path
# platform is a Joy checkout, where the runtime lives in the checkout's
# www/. The copy lands in client/www/, served like everything else there.
copy_runtime! = || {
	url = platform_url!()?
	src = if url.starts_with("https://") or url.starts_with("http://") {
		hash = match url.split_last("/") {
			Ok(at_slash) => at_slash.after.drop_suffix(".tar.zst")
			Err(_) => url.drop_suffix(".tar.zst")
		}
		"${package_cache!()}/${hash}/www/runtime.js"
	} else {
		# The header's path is relative to client/main.roc, this script runs
		# one directory up.
		"client/${url.drop_suffix("platform/main.roc")}www/runtime.js"
	}
	if Path.utf8(src).is_file!()? {
		match Path.utf8(src).copy!(Path.utf8("client/www/runtime.js")) {
			Ok({}) => Ok({})
			Err(e) => fail!("could not copy ${src} to client/www/runtime.js: ${Str.inspect(e)}")
		}
	} else {
		fail!("no runtime.js at ${src}. Is client/main.roc's platform a Joy bundle or checkout?")
	}
}

# Where roc keeps the packages it downloads, found the way roc finds it:
# XDG_CACHE_HOME when set, else %LOCALAPPDATA% (Windows), else ~/.cache.
package_cache! = || {
	base = match Env.var_str!("XDG_CACHE_HOME") {
		Ok(xdg) => xdg
		Err(_) =>
			match (System.target!().os(), Env.var_str!("LOCALAPPDATA")) {
				(Windows(_), Ok(local)) => local
				_ => {
					home = Env.var_str!("HOME") ?? ""
					"${home}/.cache"
				}
			}
	}
	"${base}/roc/packages"
}

# The platform bundle URL out of client/main.roc's header.
platform_url! = || {
	source = Str.from_utf8_lossy(Path.utf8("client/main.roc").read_bytes!()?)
	match source.split_first("platform \"") {
		Ok(at_platform) =>
			match at_platform.after.split_first("\"") {
				Ok(at_quote) => Ok(at_quote.before)
				Err(_) => fail!("could not read the platform URL out of client/main.roc")
			}

		Err(_) => fail!("could not read the platform URL out of client/main.roc")
	}
}

# roc exits 0 even when it reports errors, so the summary line decides, not
# the exit code. Any warning, an error, or a module that never got written
# fails the build.
build_app! = || {
	output = capture!(
		Cmd.new_str("roc")
			.args_str(["build", "--target=wasm32", "--no-cache", "--output=${out_path}", "client/main.roc"]),
	)?
	clean = match output.split_on("\n").keep_oks(summary_counts).last() {
		Ok(counts) => counts.errors == 0 and counts.warnings == 0
		Err(_) => Bool.False
	}

	if clean and Path.utf8(out_path).is_file!()? {
		Ok({})
	} else {
		Stderr.line!(output)?
		fail!("roc build failed for client/main.roc")
	}
}

# Read the counts out of a line like "0 errors and 1 warning found in 704ms".
# Lines that are not a summary fail to parse and are skipped by the caller.
# WORKAROUND: roc-lang/roc#12707. Without this annotation roc can panic with
# `guarded list invalidated` while building. Drop the annotation when fixed.
summary_counts : Str -> Try({ errors : U64, warnings : U64 }, [NotFound])
summary_counts = |line| {
	at_error = line.split_first(" error")?
	at_and = at_error.after.split_first(" and ")?
	at_warning = at_and.after.split_first(" warning")?
	errors = U64.from_str(at_error.before.trim()).map_err(|_| NotFound)?
	warnings = U64.from_str(at_warning.before.trim()).map_err(|_| NotFound)?
	Ok({ errors, warnings })
}

# roc spreads its diagnostics across stdout and stderr, and a run that reports
# errors can exit 0, so gather both streams whatever the exit code was.
capture! = |cmd| {
	match cmd.run!() {
		Ok(output) => Ok(Str.from_utf8_lossy(output.stdout_bytes.concat(output.stderr_bytes)))
		Err(_) => fail!("could not run ${cmd.to_str()}")
	}
}
