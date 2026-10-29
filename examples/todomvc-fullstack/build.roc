#!/usr/bin/env roc
# One-off build of the client: compile client/main.roc to client/www/app.wasm
# and put Joy's runtime.js next to it, where the server serves the rest of
# client/www/ from. Both are gitignored. Run from this directory.
#
#   ./build.roc
#   ./build.roc --release
#
# The plain build is for development: its runtime.js holds every browser
# feature, so it stays good while ./watch-client.roc rebuilds the wasm.
# `--release` builds what you deploy, optimized for size and with a
# runtime.js holding only the features the client calls.
#
# The server is not built here: `roc server/main.roc` compiles it on start
# (see watch-server.roc).
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
	joy_runtime: "../../tools/runtime/main.roc",
}

import pf.Cmd
import pf.Env
import pf.OsStr
import pf.Path
import pf.Stderr
import pf.System
import joy_runtime.JoyRuntime
import Util exposing [fail!]

out_path = "client/www/app.wasm"

main! = |args| {
	release = args.any(|arg| OsStr.to_str_try(arg) == Ok("--release"))

	check_wasm_host!()?

	# roc can exit 0 without writing anything, so drop the wasm up front and
	# check that it came back. Something stale mustn't reach the browser.
	drop!(out_path)?

	build_app!(release)?

	write_runtime!(release)
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

# The page's runtime.js is Joy's client runtime with the code of every
# browser feature, or for a release only of those the client calls (see
# Joy's tools/runtime), made from the www/ that ships beside the platform so
# it always matches it. A bundle platform (by URL, https or the localhost
# http Joy's release gate serves drafts over) sits in roc's package cache
# after the build, so its www/ is read there. A path platform is a Joy
# checkout, with www/ in the checkout. It lands in client/www/, served like
# everything else there.
write_runtime! = |release| {
	url = platform_url!()?
	joy_www = if url.starts_with("https://") or url.starts_with("http://") {
		hash = match url.split_last("/") {
			Ok(at_slash) => at_slash.after.drop_suffix(".tar.zst")
			Err(_) => url.drop_suffix(".tar.zst")
		}
		"${package_cache!()}/${hash}/www"
	} else {
		# The header's path is relative to client/main.roc, this script runs
		# one directory up.
		"client/${url.drop_suffix("platform/main.roc")}www"
	}
	core = match Path.utf8("${joy_www}/runtime.js").read_utf8!() {
		Ok(js) => js
		Err(_) => return fail!("no runtime.js in ${joy_www}. Is client/main.roc's platform a Joy bundle or checkout?")
	}
	features = (Path.utf8("${joy_www}/features").list!() ?? [])
		.keep_if(|entry| Path.display(entry).ends_with(".js"))
		.map_try!(|entry| entry.read_utf8!())?
	runtime = if release {
		wasm = Path.utf8(out_path).read_bytes!()?
		JoyRuntime.generate({ core, features, wasm })
	} else {
		JoyRuntime.full({ core, features })
	}
	match runtime {
		Ok(js) => Path.utf8("client/www/runtime.js").write_utf8!(js)
		Err(problem) => fail!("could not make client/www/runtime.js: ${Str.inspect(problem)}")
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
build_app! = |release| {
	opt = if release ["--opt=size"] else []
	output = capture!(
		Cmd.new(OsStr.from_str("roc"))
			.args(["build", "--target=wasm32", "--no-cache", "--output=${out_path}"].concat(opt).append("client/main.roc").map(OsStr.from_str)),
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
