#!/usr/bin/env roc
## The tests of ./joy. Each one makes a project in a temporary directory,
## runs ./joy in it, and checks what it printed, wrote and served.
##
## Run from the Joy repository's root:
##
##     roc cli/tests.roc                 # every test
##     roc cli/tests.roc dev             # the tests whose name contains "dev"
##
## The bundles are built from Joy's platform in this checkout, so its wasm
## host must be built, and joy-html must be reachable or in roc's cache.
app [main!] {
	http: "https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
	pf: platform "https://github.com/growthagent/joy-cli-platform/releases/download/0.1.0-rc1/71QJT9cSt2W6XM4ovm4w6A2PAnq9uUpzn7jxT8PiTGqX.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.Http
import pf.Monotonic
import pf.OsStr
import pf.Path
import pf.Server
import pf.Sleep
import pf.Stderr
import pf.Stdout
import http.Request
import http.Response

## A project to test in: where it is, where ./joy is, and where Joy is.
## `roc_cache` is the ROC_CACHE_DIR every ./joy run gets, one for the whole
## run, so the builds stay warm across projects.
Ctx : { dir : Str, joy : Str, joy_root : Str, roc_cache : Str }

main! : List(OsStr) => Try({}, _)
main! = |args| {
	filter =
		match args.map(OsStr.display) {
			[given, ..] => given
			[] => ""
		}
	joy_root = Path.display(Env.cwd!()?)
	if !(Path.utf8("cli/main.roc").is_file!() ?? False) {
		Stderr.line!("Run the tests from the Joy repository's root.")?
		return Err(Exit(2))
	}
	Stdout.line!("Building ./joy")?
	Path.utf8("cli/target").create_all!()?
	built = Cmd.new(OsStr.from_str("roc")).args(["build", "--opt=speed", "--output=cli/target/joy", "cli/main.roc"].map(OsStr.from_str)).run!()?
	if !(Path.utf8("cli/target/joy").is_file!() ?? False) {
		Stderr.line!(Str.from_utf8_lossy(built.stdout_bytes.concat(built.stderr_bytes)))?
		return Err(Exit(1))
	}
	joy = "${joy_root}/cli/target/joy"
	chosen = tests.keep_if(|(name, _)| name.contains(filter))
	var $failed = []
	for (name, test!) in chosen {
		started = Monotonic.now!()
		# The real path: macOS keeps its temp dirs behind a symlink, and platform_from
		# counts the folders it climbs.
		outcome = Env.with_temp_dir!(|dir| test!({ dir: Path.display(dir.canonicalize!() ?? dir), joy, joy_root, roc_cache: "${joy_root}/cli/target/roc-cache" }))
		took = Monotonic.since(Monotonic.now!(), started).to_millis()
		match outcome {
			Ok({}) => Stdout.line!("ok    ${name} (${took.to_str()} ms)")?
			Err(CallbackErr(Failed(why))) => {
				Stdout.line!("FAIL  ${name}: ${why}")?
				$failed = $failed.append(name)
			}
			Err(other) => {
				Stdout.line!("FAIL  ${name}: ${Str.inspect(other)}")?
				$failed = $failed.append(name)
			}
		}
	}
	if $failed.is_empty() {
		Stdout.line!("All ${chosen.len().to_str()} tests passed")
	} else {
		Stdout.line!("${$failed.len().to_str()} of ${chosen.len().to_str()} tests failed: ${Str.join_with($failed, ", ")}")?
		Err(Exit(1))
	}
}

tests : List((Str, (Ctx => Try({}, [Failed(Str)]))))
tests = [
	("bundles finds apps by their headers", bundles_by_header!),
	("bundles names ids and tags by path", bundles_ids_and_tags!),
	("bundles lists Joy apps outside client/", bundles_strays!),
	("bundles --json", bundles_json!),
	("build writes hashed bundles, the loader, the runtime and assets.json", build_basic!),
	("build hashes stay the same for the same source", build_stable_hashes!),
	("build copies public/ and rewrites its HTML", build_public!),
	("build hashes assets/", build_assets!),
	("build names hashed files in stylesheets", build_stylesheet_urls!),
	("build warns about paths that will 404", build_broken_paths!),
	("build names a file it cannot read", build_unreadable!),
	("the guide's ./joy commands and flags exist", guide_flags!),
	("the guide's Sass commands build", guide_sass_build!),
	("the guide's Sass command watches", guide_sass_watch!),
	("the guide's esbuild commands build", guide_esbuild_build!),
	("the guide's esbuild command watches", guide_esbuild_watch!),
	("build refuses a path that two things would take", build_conflicts!),
	("build guards --out-dir", build_out_dir_guards!),
	("build fails on a broken bundle and leaves no wasm", build_broken!),
	("build fails on a warning in the project's own files", build_own_warning!),
	("build --debug writes the whole runtime", build_debug!),
	("build refuses bundles on different releases", build_mixed_releases!),
	("build builds the server, and --no-server skips it", build_server!),
	("the server and the bundles build with roc caches of their own", build_caches!),
	("a build that swaps in generated/ has roc caches of its own", build_caches_replaced!),
	("build passes flags after -- to roc", build_roc_flags!),
	("build reports bad options, and help shows them all", build_bad_options!),
	("dev serves the pages of a project without a server", dev_serves_pages!),
	("dev rebuilds what a change reaches and tells the pages", dev_rebuilds!),
	("dev rebuilds every bundle a shared module reaches, and only those", dev_shared_module!),
	("dev builds a new bundle and forgets a removed one", dev_new_and_removed_bundles!),
	("dev reports changes in public/ and assets/", dev_assets!),
	("dev never fails on a warning", dev_warning!),
	("dev with --poll", dev_poll!),
	("dev takes the next port when one is taken", dev_next_port!),
	("dev starts, restarts and keeps the project's server", dev_server!),
	("dev with --no-server sends events only", dev_no_server!),
	("dev stops everything on Ctrl-C", dev_ctrl_c!),
	("dev runs --watch commands until it stops", dev_watch!),
	("dev recovers when --watch writes an asset after the first build", dev_watch_first_start!),
	("build runs --before commands, and stops when one fails", build_before!),
	("dev is the front door with --proxy", dev_front_door!),
	("dev answers 502 when a backend is down", dev_backend_down!),
	("dev refuses a malformed --proxy", dev_bad_proxy!),
	("dev plays the proxy for a server that sits behind one", dev_behind_proxy!),
	("dev says when a server does not serve its files", dev_server_without_files!),
	("generated/ is written only when a header names it", generated_only_when_named!),
	("build compiles against hashed names and the server reads them", generated_build!),
	("a server refuses another build's assets.json", generated_refuses!),
	("a missing asset is a compile error", generated_missing_asset!),
	("two bundles with one tag are refused", generated_same_tag!),
	("dev rewrites generated/ when a file is added", generated_dev!),
	("init starts a project from a template, and the project builds", init_template!),
	("init refuses a folder with files and keeps dot files", init_folder_rules!),
	("init only installs ./joy where there is an app", init_existing_app!),
	("init never asks without a terminal, and needs a checkout", init_no_input!),
]

# Fixtures

html_package = "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst"

## The platform of the fixture servers, the same release ./joy is built on.
cli_platform = "https://github.com/growthagent/joy-cli-platform/releases/download/0.1.0-rc1/71QJT9cSt2W6XM4ovm4w6A2PAnq9uUpzn7jxT8PiTGqX.tar.zst"

## A small Joy app that renders `label`, importing `imports`, with `extra`
## at the end of the file.
app_source : Str, Str, Str, Str -> Str
app_source = |platform_path, label, import_lines, extra|
	Str.join_with(
		[
			"app [Model, Msg, init, update, view, subscriptions] {",
			"\tpf: platform \"${platform_path}\",",
			"\thtml: \"${html_package}\",",
			"}",
			"",
			"import html.Html exposing [div, text]",
			"import pf.Effect",
			import_lines,
			"",
			"Model : {}",
			"",
			"Msg : [Nothing]",
			"",
			"subscriptions = |_model| []",
			"",
			"init : Str -> (Model, List(Effect(Msg)))",
			"init = |_| ({}, [])",
			"",
			"view : Model -> Html(Msg)",
			"view = |_model| div([], [text(${label})])",
			"",
			"update : Model, Msg -> (Model, List(Effect(Msg)))",
			"update = |model, _msg| (model, [])",
			extra,
		],
		"\n",
	)

## The path from `file`'s folder in the project to Joy's platform.
platform_from : Ctx, Str -> Str
platform_from = |ctx, file| {
	depth = "${ctx.dir}/${file}".split_on("/").drop_if(|part| part.is_empty()).len() - 1
	"${Str.repeat("../", depth)}${ctx.joy_root.drop_prefix("/")}/platform/main.roc"
}

## Write a bundle that renders `label`.
bundle! : Ctx, Str, Str => Try({}, [Failed(Str)])
bundle! = |ctx, file, label| write!(ctx, file, app_source(platform_from(ctx, file), "\"${label}\"", "", ""))

write! : Ctx, Str, Str => Try({}, [Failed(Str)])
write! = |ctx, file, content| {
	path = "${ctx.dir}/${file}"
	match path.split_last("/") {
		Ok({ before, .. }) => Path.utf8(before).create_all!() ? |_| Failed("could not make the folder of ${file}")
		Err(_) => {}
	}
	Path.utf8(path).write_utf8!(content).map_err(|_| Failed("could not write ${file}"))
}

read! : Ctx, Str => Try(Str, [Failed(Str)])
read! = |ctx, file| Path.utf8("${ctx.dir}/${file}").read_utf8!().map_err(|_| Failed("could not read ${file}"))

exists! : Ctx, Str => Bool
exists! = |ctx, file| Path.utf8("${ctx.dir}/${file}").exists!() ?? False

files_in! : Ctx, Str => List(Str)
files_in! = |ctx, dir|
	(Path.utf8("${ctx.dir}/${dir}").list!() ?? []).map(|entry| Path.display(entry).drop_prefix("${ctx.dir}/${dir}/"))

## A small server on joy-cli-platform that answers every request with
## `body`, on the port in $PORT, and prints what $JOY_ASSETS_JSON says.
server_source : Ctx, Str -> Str
server_source = |ctx, body| server_answering(ctx, 200, body)

## [server_source] with another status than 200.
server_answering : Ctx, U16, Str -> Str
server_answering = |_ctx, status, body| {
	Str.join_with(
		[
			"app [main!] {",
			"\thttp: \"https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst\",",
			"\tpf: platform \"${cli_platform}\",",
			"}",
			"",
			"import pf.Env",
			"import pf.OsStr",
			"import pf.Server",
			"import pf.Sleep",
			"import pf.Stdout",
			"import http.Response",
			"",
			"main! : List(OsStr) => Try({}, _)",
			"main! = |_args| {",
			"\tassets = Env.var_str!(OsStr.from_str(\"JOY_ASSETS_JSON\")) ?? \"unset\"",
			"\tport = U16.from_str(Env.var_str!(OsStr.from_str(\"PORT\")) ?? \"0\") ?? 0",
			"\tserver = Server.start!({ port: port }, |_| Ok(Server.respond(Response.from_status(${status.to_str()}).with_body(Str.to_utf8(\"${body}\")))))?",
			"\tStdout.line!(\"app listening on \${U16.to_str(server.port())} with \${assets}\")?",
			"\t_ = Sleep.millis!(1_000_000_000)",
			"\tServer.stop!(server)",
			"\tOk({})",
			"}",
		],
		"\n",
	)
}

# Running ./joy

Ran : { code : I32, out : Str }

run_joy! : Ctx, List(Str) => Try(Ran, [Failed(Str)])
run_joy! = |ctx, args| run_joy_with!(ctx, args, [])

## Run ./joy with `envs` added to its environment.
run_joy_with! : Ctx, List(Str), List((Str, Str)) => Try(Ran, [Failed(Str)])
run_joy_with! = |ctx, args, envs| {
	output =
		envs
			.fold(Cmd.new(OsStr.from_str(ctx.joy)).env(OsStr.from_str("ROC_CACHE_DIR"), OsStr.from_str(ctx.roc_cache)), |cmd, (key, value)| cmd.env(OsStr.from_str(key), OsStr.from_str(value)))
			.args(args.map(OsStr.from_str))
			.cwd(Path.utf8(ctx.dir))
			.stderr(MergeWithStdout)
			.timeout(Duration.minutes(5))
			.run!()
			? |err| Failed("./joy ${Str.join_with(args, " ")} did not run: ${Str.inspect(err)}")
	code =
		match output.status {
			Exited(exit) => exit
			Signaled(signal) => 128 + signal
		}
	Ok({ code, out: Str.from_utf8_lossy(output.stdout_bytes) })
}

## Run ./joy and require the exit code.
joy_ok! : Ctx, List(Str), I32 => Try(Str, [Failed(Str)])
joy_ok! = |ctx, args, expected| joy_with!(ctx, args, expected, [])

## [joy_ok!] with `envs` added to the environment.
joy_with! : Ctx, List(Str), I32, List((Str, Str)) => Try(Str, [Failed(Str)])
joy_with! = |ctx, args, expected, envs| {
	ran = run_joy_with!(ctx, args, envs)?
	if ran.code == expected {
		Ok(ran.out)
	} else {
		Err(Failed("./joy ${Str.join_with(args, " ")} exited ${ran.code.to_str()}, not ${expected.to_str()}:\n${ran.out}"))
	}
}

check : Bool, Str -> Try({}, [Failed(Str)])
check = |condition, why| if (condition) Ok({}) else Err(Failed(why))

contains : Str, Str -> Try({}, [Failed(Str)])
contains = |text, part| check(text.contains(part), "expected ${Str.inspect(part)} in:\n${text}")

lacks : Str, Str -> Try({}, [Failed(Str)])
lacks = |text, part| check(!text.contains(part), "did not expect ${Str.inspect(part)} in:\n${text}")

## The hashed wasm a build gave a bundle, from assets.json.
wasm_name! : Ctx, Str => Try(Str, [Failed(Str)])
wasm_name! = |ctx, id| {
	json = read!(ctx, "dist/assets.json")?
	match json.split_first("\"${id}\": \"") {
		Ok({ after, .. }) =>
			match after.split_first("\"") {
				Ok({ before, .. }) => Ok(before)
				Err(_) => Err(Failed("no wasm for ${id} in assets.json"))
			}
		Err(_) => Err(Failed("no wasm for ${id} in assets.json:\n${json}"))
	}
}

# ./joy bundles

bundles_by_header! : Ctx => Try({}, [Failed(Str)])
bundles_by_header! = |ctx| {
	# Comments before the header, and a header over several lines.
	write!(ctx, "client/commented.roc", "# A bundle\n## with comments\n\n${app_source(platform_from(ctx, "client/commented.roc"), "\"x\"", "", "")}")?
	bundle!(ctx, "client/plain.roc", "x")?
	# A module, an app on another platform and a dot folder are not bundles.
	write!(ctx, "client/Helper.roc", "Helper :: [].{\n\tlabel : Str\n\tlabel = \"x\"\n}\n")?
	write!(ctx, "client/other.roc", "app [main!] { pf: platform \"../somewhere/platform/main.roc\" }\n\nmain! = |_| Ok({})\n")?
	bundle!(ctx, "client/.hidden/secret.roc", "x")?
	out = joy_ok!(ctx, ["bundles"], 0)?
	contains(out, "commented  Commented  client/commented.roc  dist/client/commented/")?
	contains(out, "plain  Plain")?
	lacks(out, "Helper")?
	lacks(out, "other")?
	lacks(out, "secret")
}

bundles_ids_and_tags! : Ctx => Try({}, [Failed(Str)])
bundles_ids_and_tags! = |ctx| {
	bundle!(ctx, "client/Checkout/cart.roc", "cart")?
	bundle!(ctx, "client/Store/on_sale.roc", "on sale")?
	bundle!(ctx, "client/work-with-us.roc", "work")?
	out = joy_ok!(ctx, ["bundles"], 0)?
	contains(out, "Checkout/cart  CheckoutCart  client/Checkout/cart.roc  dist/client/Checkout/cart/")?
	contains(out, "Store/on_sale  StoreOnSale")?
	contains(out, "work-with-us  WorkWithUs")
}

bundles_strays! : Ctx => Try({}, [Failed(Str)])
bundles_strays! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	bundle!(ctx, "tests/fixture.roc", "fixture")?
	out = joy_ok!(ctx, ["bundles"], 0)?
	contains(out, "found, not built: tests/fixture.roc, a Joy app outside client/")?
	lacks(out, "fixture  Fixture")
}

bundles_json! : Ctx => Try({}, [Failed(Str)])
bundles_json! = |ctx| {
	bundle!(ctx, "client/Checkout/cart.roc", "cart")?
	out = joy_ok!(ctx, ["bundles", "--json"], 0)?
	contains(out, "[{ \"id\": \"Checkout/cart\", \"tag\": \"CheckoutCart\", \"file\": \"client/Checkout/cart.roc\", \"output\": \"dist/client/Checkout/cart/\" }]")?
	empty = joy_ok!({ ..ctx, dir: "${ctx.dir}/client/Checkout" }, ["bundles"], 0)?
	contains(empty, "No bundles under client/.")
}

# ./joy build

build_basic! : Ctx => Try({}, [Failed(Str)])
build_basic! = |ctx| {
	bundle!(ctx, "client/catalog.roc", "catalog")?
	bundle!(ctx, "client/Checkout/cart.roc", "cart")?
	out = joy_ok!(ctx, ["build", "--jobs", "2"], 0)?
	contains(out, "Built 2 bundles into dist/")?
	catalog = wasm_name!(ctx, "catalog")?
	cart = wasm_name!(ctx, "Checkout/cart")?
	check(catalog.starts_with("catalog/app.") and catalog.ends_with(".wasm") and catalog != "catalog/app.wasm", "catalog's wasm is not hashed: ${catalog}")?
	check(exists!(ctx, "dist/client/${catalog}") and exists!(ctx, "dist/client/${cart}"), "the hashed wasm files are missing")?
	check(!exists!(ctx, "dist/client/catalog/app.wasm"), "the plain wasm name is left behind")?
	json = read!(ctx, "dist/assets.json")?
	contains(json, "\"roots\": { \"joy\": \"client\", \"assets\": \"client\", \"public\": \"client\" }")?
	loader = files_in!(ctx, "dist/client").keep_if(|name| name.starts_with("joy.") and name.ends_with(".js"))
	check(loader.len() == 1, "expected one hashed joy.js, found ${Str.inspect(loader)}")?
	contains(json, "\"joy\": \"${loader.first() ?? "?"}\"")?
	runtime = read!(ctx, "dist/client/runtime.js")?
	contains(runtime, "Features these apps use (see tools/runtime): none")?
	hashed_runtime = files_in!(ctx, "dist/client").keep_if(|name| name.starts_with("runtime.") and name != "runtime.js")
	check(hashed_runtime.len() == 1, "expected one hashed runtime, found ${Str.inspect(hashed_runtime)}")?
	runtime_name = hashed_runtime.first() ?? "?"
	contains(json, "\"runtime\": \"${runtime_name}\"")?
	contains(read!(ctx, "dist/client/${loader.first() ?? "?"}")?, "from './${runtime_name}'")?
	marker = read!(ctx, "dist/.joy-output")?
	contains(marker, "\"debug\": false")?
	contains(marker, "\"complete\": true")
}

build_stable_hashes! : Ctx => Try({}, [Failed(Str)])
build_stable_hashes! = |ctx| {
	bundle!(ctx, "client/app.roc", "same")?
	_ = joy_ok!(ctx, ["build"], 0)?
	first = wasm_name!(ctx, "app")?
	_ = joy_ok!(ctx, ["build"], 0)?
	second = wasm_name!(ctx, "app")?
	check(first == second, "the same source got two names: ${first} and ${second}")?
	bundle!(ctx, "client/app.roc", "different")?
	_ = joy_ok!(ctx, ["build"], 0)?
	third = wasm_name!(ctx, "app")?
	check(third != first, "a changed bundle kept its name ${first}")
}

build_public! : Ctx => Try({}, [Failed(Str)])
build_public! = |ctx| {
	bundle!(ctx, "client/catalog.roc", "catalog")?
	write!(ctx, "public/index.html", "<div data-joy-bundle=\"catalog\"></div>\n<script type=\"module\" src=\"./joy.js\"></script>\n")?
	write!(ctx, "public/docs/page.html", "<!-- <script src=\"../joy.js\"></script> -->\n<link rel=stylesheet href=/static/css/site.css>\n<link rel=\"stylesheet\" href=\"../css/site.css?v=2\">\n<div data-joy-bundle=\"catalog\"></div>\n<script type=\"module\" src=../joy.js></script>\n")?
	write!(ctx, "assets/css/site.css", "h1 { color: teal }\n")?
	write!(ctx, "public/robots.txt", "User-agent: *\n")?
	write!(ctx, "public/.well-known/security.txt", "Contact: x\n")?
	_ = joy_ok!(ctx, ["build", "--client-url", "/static"], 0)?
	wasm = wasm_name!(ctx, "catalog")?
	index = read!(ctx, "dist/client/index.html")?
	contains(index, "data-joy-bundle=\"catalog\" data-joy-wasm=\"${wasm}\"")?
	lacks(index, "\"./joy.js\"")?
	contains(index, "src=\"./joy.")?
	page = read!(ctx, "dist/client/docs/page.html")?
	contains(page, "data-joy-wasm=\"../${wasm}\"")?
	contains(page, "<!-- <script src=\"../joy.js\"></script> -->")?
	lacks(page, "src=../joy.js>")?
	css = files_in!(ctx, "dist/client/css").first() ?? "?"
	contains(page, "href=/static/css/${css}>")?
	contains(page, "href=\"../css/${css}?v=2\"")?
	robots = read!(ctx, "dist/client/robots.txt")?
	check(robots == "User-agent: *\n", "robots.txt changed on the way")?
	check(exists!(ctx, "dist/client/.well-known/security.txt"), "public/.well-known was not copied")?
	json = read!(ctx, "dist/assets.json")?
	contains(json, "\"public\": [")?
	contains(json, "\"robots.txt\"")
}

build_assets! : Ctx => Try({}, [Failed(Str)])
build_assets! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "assets/css/site.css", "h1 { color: teal }\n")?
	write!(ctx, "assets/fonts/hind", "not really a font")?
	_ = joy_ok!(ctx, ["build"], 0)?
	json = read!(ctx, "dist/assets.json")?
	css = files_in!(ctx, "dist/client/css")
	check(css.len() == 1 and (css.first() ?? "").starts_with("site.") and (css.first() ?? "").ends_with(".css") and css != ["site.css"], "site.css was not hashed: ${Str.inspect(css)}")?
	contains(json, "\"css/site.css\": \"css/${css.first() ?? "?"}\"")?
	copied = read!(ctx, "dist/client/css/${css.first() ?? "?"}")?
	check(copied == "h1 { color: teal }\n", "the hashed copy differs")?
	fonts = files_in!(ctx, "dist/client/fonts")
	check(fonts.len() == 1 and (fonts.first() ?? "").starts_with("hind."), "a file without an extension was not hashed: ${Str.inspect(fonts)}")
}

build_broken_paths! : Ctx => Try({}, [Failed(Str)])
build_broken_paths! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "assets/js/main.js", "import \"lit\"\n// import \"./commented.js\"\nimport \"./kept.js\"\nimport \"../runtime.js\"\n")?
	write!(ctx, "assets/css/site.css", "@import \"./base.css\";\na { background: url(../kept.png) } b { background: url(/server/route.png) }\n")?
	write!(ctx, "assets/css/base.css", "p {}\n")?
	write!(ctx, "public/js/kept.js", "import \"./other.js\"\n")?
	write!(ctx, "public/js/other.js", "export {}")?
	write!(ctx, "public/kept.png", "png")?
	quiet = joy_ok!(ctx, ["build"], 0)?
	check(!quiet.contains("Warning"), "a build warned about paths that work:\n${quiet}")?

	write!(ctx, "assets/js/main.js", "import{a}from\"./dep.js\";await import(`../lib/lazy.mjs`);import\"./typo.js\"")?
	write!(ctx, "assets/js/dep.js", "export const a = 1")?
	write!(ctx, "assets/lib/lazy.mjs", "import \"./gone.js\"")?
	write!(ctx, "assets/css/site.css", "@import \"./nope.css\";\na { background: url(gone.png) }\n")?
	write!(ctx, "public/js/kept.js", "import \"./dep.js\"\n")?
	write!(ctx, "public/js/page.css", "a { background: url(dep.js) }\n")?
	# Not UTF-8, which must not hide what the file imports.
	out = joy_ok!(ctx, ["build", "--before", "printf 'const s = \"\\351\";\\nimport \"./dep.js\"\\n' > assets/js/latin.js"], 0)?
	contains(out, "assets/js/main.js imports ./dep.js, which a build gives a hashed name")?
	contains(out, "assets/js/main.js imports ../lib/lazy.mjs, which a build gives a hashed name")?
	contains(out, "assets/js/main.js imports ./typo.js, which is in neither assets/ nor public/")?
	contains(out, "assets/lib/lazy.mjs imports ./gone.js, which is in neither assets/ nor public/")?
	contains(out, "assets/js/latin.js imports ./dep.js, which a build gives a hashed name")?
	contains(out, "assets/css/site.css names ./nope.css, which is in neither assets/ nor public/")?
	contains(out, "assets/css/site.css names gone.png, which is in neither assets/ nor public/")?
	contains(out, "public/js/kept.js imports ./dep.js, which a build gives a hashed name")?
	contains(out, "public/js/page.css names dep.js, which a build gives a hashed name")?
	contains(out, "keep all of its modules in public/")?
	check(files_in!(ctx, "dist/client/js").any(|name| name.starts_with("main.")), "the warning stopped the build")?

	write!(ctx, "assets/js/main.js", "import \"./typo.js\"")?
	write!(ctx, "assets/js/latin.js", "export {}")?
	write!(ctx, "assets/lib/lazy.mjs", "export {}")?
	write!(ctx, "assets/css/site.css", "a {}")?
	write!(ctx, "public/js/kept.js", "export {}")?
	write!(ctx, "public/js/page.css", "a {}")?
	missing = joy_ok!(ctx, ["build"], 0)?
	contains(missing, "assets/js/main.js imports ./typo.js")?
	check(!missing.contains("keep all of its modules"), "bundling was advised for a file that does not exist:\n${missing}")
}

build_unreadable! : Ctx => Try({}, [Failed(Str)])
build_unreadable! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	refused! = |path, want| {
		chmod!(ctx, "000", path)?
		ran = run_joy!(ctx, ["build"])?
		chmod!(ctx, "755", path)?
		check(ran.code == 1, "a build exited ${ran.code.to_str()} with ${path} unreadable:\n${ran.out}")?
		contains(ran.out, want)?
		check(!ran.out.contains("Program exited"), "a raw error reached the user:\n${ran.out}")
	}
	write!(ctx, "assets/locked.js", "export {}")?
	refused!("assets/locked.js", "Could not read assets/locked.js: permission denied")?
	write!(ctx, "assets/locked.css", "a {}")?
	refused!("assets/locked.css", "Could not read assets/locked.css: permission denied")?
	write!(ctx, "public/js/locked.js", "export {}")?
	refused!("public/js/locked.js", "Could not copy public/js/locked.js to dist/client/js/locked.js: permission denied")?
	write!(ctx, "public/page.html", "<p></p>")?
	refused!("public/page.html", "Could not read public/page.html: permission denied")?
	refused!("public/js", "Could not read public/js/: permission denied")
}

## The commands of the guide's Optimizing assets page that use `tool`, so these
## tests run what it tells people to run.
guide_commands! : Ctx, Str => Try(List(Str), [Failed(Str)])
guide_commands! = |ctx, tool| {
	if !has_tool!(tool) {
		return Err(Failed("${tool} is not on the PATH. The nix dev shell has it, and CI installs it."))
	}
	page = Path.utf8("${ctx.joy_root}/guide/Topic/OptimizingAssets.roc").read_utf8!() ? |_| Failed("could not read the guide's Optimizing assets page")
	Ok(page.split_on("\n").map(Str.trim).keep_if(|line| line.starts_with("\\\\$ ") and line.contains(tool)).map(|line| line.drop_prefix("\\\\$ ")))
}

chmod! : Ctx, Str, Str => Try({}, [Failed(Str)])
chmod! = |ctx, mode, path| {
	ran = Cmd.new(OsStr.from_str("chmod")).args([mode, path].map(OsStr.from_str)).cwd(Path.utf8(ctx.dir)).run!() ? |err| Failed("chmod: ${Str.inspect(err)}")
	check(ran.status == Exited(0), "chmod ${mode} ${path} failed")
}

has_tool! : Str => Bool
has_tool! = |tool|
	match Cmd.new(OsStr.from_str(tool)).args([OsStr.from_str("--version")]).run!() {
		Ok(output) => output.status == Exited(0)
		Err(_) => False
	}

## The one command the page shows `--before` or `--watch` with.
guide_flag_value! : Ctx, Str, Str => Try(Str, [Failed(Str)])
guide_flag_value! = |ctx, tool, flag| {
	lines = guide_commands!(ctx, tool)?.keep_if(|line| line.contains(flag))
	match lines {
		[line] =>
			match line.split_first("${flag} \"") {
				Ok({ after, .. }) => Ok(after.drop_suffix("\""))
				Err(_) => Err(Failed("no quoted ${flag} in: ${line}"))
			}

		_ => Err(Failed("expected one ${flag} line for ${tool}, found ${Str.inspect(lines)}"))
	}
}

## Nothing is still running the command `./joy dev` was given.
stopped! : Str => Try({}, [Failed(Str)])
stopped! = |command| {
	left = Cmd.new(OsStr.from_str("pgrep")).args(["-f", command].map(OsStr.from_str)).run!() ? |err| Failed("pgrep: ${Str.inspect(err)}")
	check(left.status == Exited(1), "${command} outlived ./joy dev:\n${Str.from_utf8_lossy(left.stdout_bytes)}")
}

## Wait for a file the project's watcher writes to say `text`.
file_says! : Ctx, Str, Str => Try({}, [Failed(Str)])
file_says! = |ctx, file, text| {
	var $tries = 0
	while $tries < 150 {
		if (read!(ctx, file) ?? "").contains(text) {
			return Ok({})
		}
		_ = Sleep.millis!(100)
		$tries = $tries + 1
	}
	Err(Failed("${file} never said ${text}: ${read!(ctx, file) ?? "(no such file)"}"))
}

## The one file in `folder` of the build with a hashed name after `stem`.
built_file! : Ctx, Str, Str => Try(Str, [Failed(Str)])
built_file! = |ctx, folder, stem| {
	match files_in!(ctx, folder).keep_if(|name| name.starts_with("${stem}.")) {
		[name] => read!(ctx, "${folder}/${name}")
		other => Err(Failed("expected one ${stem} in ${folder}, found ${Str.inspect(other)}"))
	}
}

guide_flags! : Ctx => Try({}, [Failed(Str)])
guide_flags! = |ctx| {
	commands = ["dev", "build", "bundles", "init"]
	helps = commands.map_try!(|command| joy_ok!(ctx, [command, "--help"], 0).map_ok(|help| (command, flags_in(help))))?
	topics = Path.utf8("${ctx.joy_root}/guide/Topic").list!() ? |_| Failed("could not list the guide's topics")
	var $checked = 0
	for topic in topics {
		source = topic.read_utf8!() ? |_| Failed("could not read ${Path.display(topic)}")
		var $in_shell = False
		for line in source.split_on("\n") {
			# A code block's language comes first, on a line of its own.
			trimmed = line.trim()
			if ["Sh,", "Roc,", "Js,", "Html,", "Text,"].contains(trimmed) {
				$in_shell = trimmed == "Sh,"
			}
			sample = $in_shell and trimmed.starts_with("\\\\")
			for after in line.split_on("./joy ").drop_first(1) {
				# A sample's quotes hold another tool's flags. Prose ends at its string's.
				words = (if (sample) outside_quotes(after) else after.split_on("\"").first() ?? after).split_on(" ")
				command = words.first() ?? ""
				match helps.find_first(|(name, _)| name == command) {
					Ok((_, help)) => {
						$checked = $checked + 1
						for word in words.drop_first(1) {
							name = word.split_on("=").first() ?? word
							if name.starts_with("--") and !help.contains(name) {
								return Err(Failed("${Path.display(topic)} has ./joy ${command} ${name}, which --help does not list"))
							}
						}
					}

					# A sample names a command. Prose can say anything.
					Err(_) if sample => return Err(Failed("${Path.display(topic)} has ./joy ${command}, which is no command: ${line.trim()}"))
					Err(_) => {}
				}
			}
		}
	}
	check($checked >= 9, "only ${$checked.to_str()} ./joy commands found in the guide")?

	# The ./joy page also names flags in its text, each in a code span of its own.
	every_flag = helps.map(|(_, flags)| flags).join()
	page = Path.utf8("${ctx.joy_root}/guide/Topic/JoyCli.roc").read_utf8!() ? |_| Failed("could not read the guide's ./joy page")
	named = page.split_on("text(\"--").drop_first(1).map(|after| "--${after.split_on("\"").first() ?? after}").map(|flag| (flag.split_on(" ").first() ?? flag).split_on("=").first() ?? flag)
	check(!named.is_empty(), "the guide's ./joy page names no flags")?
	unknown = named.drop_if(|flag| every_flag.contains(flag))
	check(unknown.is_empty(), "the guide's ./joy page names flags --help does not list: ${Str.inspect(unknown)}")
}

## The flags a --help text lists, each whole, so `--prox` is not `--proxy`.
flags_in : Str -> List(Str)
flags_in = |help|
	help
		.replace_each("\n", " ")
		.split_on(" ")
		.map(|word| word.split_on("=").first() ?? word)
		.keep_if(|word| word.starts_with("--"))

## `text` without what its double quotes hold.
outside_quotes : Str -> Str
outside_quotes = |text| {
	var $outside = True
	var $kept = []
	for part in text.split_on("\"") {
		if $outside {
			$kept = $kept.append(part)
		}
		$outside = !$outside
	}
	Str.join_with($kept, " ")
}

guide_sass_build! : Ctx => Try({}, [Failed(Str)])
guide_sass_build! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "styles/site.scss", "$accent: teal;\nh1 { color: $accent; }\n")?
	before = guide_flag_value!(ctx, "sass", "--before")?
	_ = joy_ok!(ctx, ["build", "--before", before], 0)?
	contains(read!(ctx, "assets/css/site.css")?, "color:teal")?
	contains(built_file!(ctx, "dist/client/css", "site")?, "color:teal")
}

guide_sass_watch! : Ctx => Try({}, [Failed(Str)])
guide_sass_watch! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "styles/site.scss", "h1 { color: teal; }\n")?
	watch = guide_flag_value!(ctx, "sass", "--watch")?
	dev = start_dev!(ctx, ["--watch", watch], [])?
	dev1 = wait_for!(dev, "built app", 1)?
	file_says!(ctx, "assets/css/site.css", "teal")?
	write!(ctx, "styles/site.scss", "h1 { color: plum; }\n")?
	file_says!(ctx, "assets/css/site.css", "plum")?
	_ = stop_dev!(dev1)?
	stopped!(watch)
}

guide_esbuild_build! : Ctx => Try({}, [Failed(Str)])
guide_esbuild_build! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "scripts/app.ts", "const greet = (who: string): string => \"hello \" + who\nconsole.log(greet(\"joy\"))\n")?
	before = guide_flag_value!(ctx, "esbuild", "--before")?
	_ = joy_ok!(ctx, ["build", "--before", before], 0)?
	script = built_file!(ctx, "dist/client", "app")?
	contains(script, "hello")?
	check(!script.contains(": string"), "esbuild left TypeScript's types in:\n${script}")?

	# Minifying what a build wrote, which keeps each file's hashed name.
	write!(ctx, "assets/site.css", "a {\n  color: red;\n}\n")?
	_ = joy_ok!(ctx, ["build"], 0)?
	minify = guide_commands!(ctx, "esbuild")?.keep_if(|line| line.starts_with("esbuild "))
	check(minify.len() == 1, "expected one esbuild line of its own, found ${Str.inspect(minify)}")?
	line = minify.first() ?? ""
	ran = Cmd.new(OsStr.from_str("sh")).args(["-c", line].map(OsStr.from_str)).cwd(Path.utf8(ctx.dir)).stderr(MergeWithStdout).run!() ? |err| Failed("${line}: ${Str.inspect(err)}")
	check(ran.status == Exited(0), "${line}:\n${Str.from_utf8_lossy(ran.stdout_bytes)}")?
	css = built_file!(ctx, "dist/client", "site")?
	check(css.trim() == "a{color:red}", "the guide's command did not minify the build: ${css}")
}

guide_esbuild_watch! : Ctx => Try({}, [Failed(Str)])
guide_esbuild_watch! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "scripts/app.ts", "console.log(\"one\" as string)\n")?
	watch = guide_flag_value!(ctx, "esbuild", "--watch")?
	dev = start_dev!(ctx, ["--watch", watch], [])?
	dev1 = wait_for!(dev, "built app", 1)?
	file_says!(ctx, "assets/app.js", "one")?
	write!(ctx, "scripts/app.ts", "console.log(\"two\" as string)\n")?
	file_says!(ctx, "assets/app.js", "two")?
	_ = stop_dev!(dev1)?
	stopped!(watch)
}

build_stylesheet_urls! : Ctx => Try({}, [Failed(Str)])
build_stylesheet_urls! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "assets/fonts/hind.woff2", "font one")?
	write!(ctx, "assets/css/base.css", "body { background: url('../images/bg.png?v=2') }\n")?
	write!(ctx, "assets/images/bg.png", "png")?
	write!(ctx, "assets/css/site.css", "@import \"base.css\";\n@font-face { src: url(\"../fonts/hind.woff2\") format(\"woff2\") }\na { b: url(/abs.png) } c { d: url(data:image/gif;base64,R0) } e { f: url(missing.png) }\n/* url(../images/bg.png) */ g { h: URL(/static/images/bg.png) } i { j: image-set(\"../images/bg.png\" 1x) } k { content: \"url(../images/bg.png)\" }\n")?
	_ = joy_with!(ctx, ["build"], 0, [("JOY_CLIENT_URL", "/static/")])?
	hashed! = |plain| {
		json = read!(ctx, "dist/assets.json")?
		match json.split_first("\"${plain}\": \"") {
			Ok({ after, .. }) => Ok(after.split_first("\"").map_ok(|{ before, .. }| before) ?? "?")
			Err(_) => Err(Failed("${plain} is not in assets.json"))
		}
	}
	font = hashed!("fonts/hind.woff2")?
	base = hashed!("css/base.css")?
	site = hashed!("css/site.css")?
	site_css = read!(ctx, "dist/client/${site}")?
	contains(site_css, "@import \"${base.drop_prefix("css/")}\";")?
	contains(site_css, "url(\"../${font}\") format(\"woff2\")")?
	contains(site_css, "url(/abs.png)")?
	contains(site_css, "url(data:image/gif;base64,R0)")?
	contains(site_css, "url(missing.png)")?
	contains(read!(ctx, "dist/client/${base}")?, "url('../${hashed!("images/bg.png")?}?v=2')")?
	background = hashed!("images/bg.png")?
	contains(site_css, "/* url(../images/bg.png) */")?
	contains(site_css, "URL(/static/${background})")?
	contains(site_css, "image-set(\"../${background}\" 1x)")?
	contains(site_css, "content: \"url(../images/bg.png)\"")?
	source = read!(ctx, "assets/css/site.css")?
	check(!source.contains(font), "the build changed the stylesheet in assets/")?
	# A changed font renames the stylesheet that names it, and not the others.
	write!(ctx, "assets/fonts/hind.woff2", "font two")?
	_ = joy_with!(ctx, ["build"], 0, [("JOY_CLIENT_URL", "/static/")])?
	check(hashed!("css/site.css")? != site, "site.css kept its name after the font it names changed")?
	check(hashed!("css/base.css")? == base, "base.css was renamed though nothing it names changed")?
	write!(ctx, "assets/css/base.css", "@import url(site.css);\n")?
	circle = joy_with!(ctx, ["build"], 1, [("JOY_CLIENT_URL", "/static/")])?
	contains(circle, "These stylesheets import each other in a circle")?
	contains(circle, "assets/css/base.css")?
	contains(circle, "assets/css/site.css")
}

build_conflicts! : Ctx => Try({}, [Failed(Str)])
build_conflicts! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "public/logo.svg", "<svg/>")?
	write!(ctx, "assets/logo.svg", "<svg/>")?
	both = joy_ok!(ctx, ["build"], 1)?
	contains(both, "logo.svg is in both public/ and assets/")?
	_ = Path.utf8("${ctx.dir}/assets/logo.svg").delete!()
	write!(ctx, "public/joy.js", "// mine")?
	loader = joy_ok!(ctx, ["build"], 1)?
	contains(loader, "public/joy.js is at a path ./joy writes itself")?
	_ = Path.utf8("${ctx.dir}/public/joy.js").delete!()
	write!(ctx, "public/app/notes.txt", "notes")?
	inside = joy_ok!(ctx, ["build"], 1)?
	contains(inside, "public/app/notes.txt is at a path ./joy writes itself")
}

build_out_dir_guards! : Ctx => Try({}, [Failed(Str)])
build_out_dir_guards! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	for dir in ["..", "../elsewhere", ".", "/tmp/joy-out", "out/../.."] {
		out = joy_ok!(ctx, ["build", "--out-dir", dir], 1)?
		contains(out, "--out-dir must name a directory inside the project")?
	}
	write!(ctx, "mine/notes.txt", "keep me")?
	refused = joy_ok!(ctx, ["build", "--out-dir", "mine"], 1)?
	contains(refused, "mine/ holds files ./joy did not write")?
	kept = read!(ctx, "mine/notes.txt")?
	check(kept == "keep me", "a refused build touched the directory")?
	# A directory ./joy wrote is emptied, so nothing stale survives.
	_ = joy_ok!(ctx, ["build", "--out-dir", "out/web"], 0)?
	write!(ctx, "out/web/client/stale.js", "old")?
	_ = joy_ok!(ctx, ["build", "--out-dir", "out/web"], 0)?
	check(!exists!(ctx, "out/web/client/stale.js"), "a stale file survived a rebuild")
}

build_broken! : Ctx => Try({}, [Failed(Str)])
build_broken! = |ctx| {
	bundle!(ctx, "client/good.roc", "good")?
	write!(ctx, "client/bad.roc", app_source(platform_from(ctx, "client/bad.roc"), "\"bad\"", "", "broken = "))?
	out = joy_ok!(ctx, ["build"], 1)?
	contains(out, "bad failed:")?
	contains(out, "1 of 2 builds failed")?
	contains(out, "built good")?
	check(!exists!(ctx, "dist/client/bad/app.wasm"), "a failed bundle left a wasm behind")?
	check(!exists!(ctx, "dist/assets.json"), "a failed build wrote assets.json")
}

build_own_warning! : Ctx => Try({}, [Failed(Str)])
build_own_warning! = |ctx| {
	write!(ctx, "client/app.roc", app_source(platform_from(ctx, "client/app.roc"), "\"app\"", "", "\nhelper = |n| {\n\tunused = 1\n\tn\n}\n"))?
	out = joy_ok!(ctx, ["build"], 1)?
	contains(out, "app failed:")?
	contains(out, "unused")
}

build_debug! : Ctx => Try({}, [Failed(Str)])
build_debug! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	_ = joy_ok!(ctx, ["build", "--debug"], 0)?
	runtime = read!(ctx, "dist/client/runtime.js")?
	contains(runtime, "Every feature, for development")?
	marker = read!(ctx, "dist/.joy-output")?
	contains(marker, "\"debug\": true")
}

build_mixed_releases! : Ctx => Try({}, [Failed(Str)])
build_mixed_releases! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "client/old.roc", app_source("https://github.com/niclas-ahden/joy/releases/download/0.1.0/Old.tar.zst", "\"old\"", "", ""))?
	out = joy_ok!(ctx, ["build"], 1)?
	contains(out, "The bundles name different Joy releases")?
	contains(out, "old: https://github.com/niclas-ahden/joy/releases/download/0.1.0/Old.tar.zst")?
	check(!exists!(ctx, "dist"), "a refused build wrote dist/")
}

build_server! : Ctx => Try({}, [Failed(Str)])
build_server! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "server/main.roc", server_source(ctx, "built"))?
	out = joy_ok!(ctx, ["build", "--server-opt", "dev"], 0)?
	contains(out, "Built 1 bundle and the server into dist/")?
	check(exists!(ctx, "dist/server/main"), "dist/server/main is missing")?
	_ = joy_ok!(ctx, ["build", "--no-server"], 0)?
	check(!exists!(ctx, "dist/server"), "--no-server built the server")?
	write!(ctx, "server/main.roc", "${server_source(ctx, "built")}\nbroken = ")?
	failed = joy_ok!(ctx, ["build", "--server-opt", "dev"], 1)?
	contains(failed, "server failed:")
}

## WORKAROUND: the server and the bundles build with roc caches of their own,
## see Compile.cache_root! and roc-lang/roc#12693 and #12701.
build_caches! : Ctx => Try({}, [Failed(Str)])
build_caches! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "server/main.roc", server_source(ctx, "built"))?
	_ = joy_with!(ctx, ["build", "--server-opt", "dev"], 0, [("ROC_CACHE_DIR", "${ctx.dir}/given")])?
	check(exists!(ctx, "given/joy/plain/servers/server"), "the server did not build in a cache of its own below ROC_CACHE_DIR")?
	check(exists!(ctx, "given/joy/plain/bundles"), "the bundles did not build in their cache below ROC_CACHE_DIR")?
	given = Path.utf8("${ctx.dir}/given").list!() ? |_| Failed("ROC_CACHE_DIR was not written")
	check(given.map(Path.display) == ["${ctx.dir}/given/joy"], "a build wrote into ROC_CACHE_DIR itself: ${Str.inspect(given.map(Path.display))}")?
	_ = joy_with!(ctx, ["build", "--server-opt", "dev"], 0, [("ROC_CACHE_DIR", "")])?
	check(exists!(ctx, ".joy/roc-cache/plain/servers/server"), "without ROC_CACHE_DIR the server did not build in .joy/roc-cache")?
	check(exists!(ctx, ".joy/roc-cache/plain/bundles"), "without ROC_CACHE_DIR the bundles did not build in .joy/roc-cache")
}

## WORKAROUND: a build that swaps in its copy of generated/ is another
## program to roc than one that does not, so it gets caches of its own, see
## Compile.cache_root! and roc-lang/roc#12693 and #12701.
build_caches_replaced! : Ctx => Try({}, [Failed(Str)])
build_caches_replaced! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "assets/css/site.css", "body {}")?
	write!(ctx, "server/main.roc", names_server_source(ctx, False))?
	_ = joy_with!(ctx, ["build", "--server-opt", "dev"], 0, [("ROC_CACHE_DIR", "${ctx.dir}/given")])?
	roots = Path.utf8("${ctx.dir}/given/joy").list!() ? |_| Failed("ROC_CACHE_DIR was not written")
	swapped = roots.map(Path.display).drop_if(|root| root.ends_with("/plain"))
	match swapped {
		[root] => check(Path.utf8("${root}/servers/server").exists!() ?? False, "the server did not build in the caches of its flags")?
		_ => return Err(Failed("the server that swaps in generated/ did not get caches of its own: ${Str.inspect(roots.map(Path.display))}"))
	}
	check(!exists!(ctx, "given/joy/plain/servers/server"), "the server built in the caches of a build without flags")
}

build_roc_flags! : Ctx => Try({}, [Failed(Str)])
build_roc_flags! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	_ = joy_ok!(ctx, ["build", "--", "--no-cache"], 0)?
	bad = joy_ok!(ctx, ["build", "--", "--no-such-roc-flag"], 1)?
	contains(bad, "app failed:")
}

build_bad_options! : Ctx => Try({}, [Failed(Str)])
build_bad_options! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	unknown = joy_ok!(ctx, ["build", "--fast"], 2)?
	contains(unknown, "The argument --fast was not recognized.")?
	missing = joy_ok!(ctx, ["build", "--opt"], 2)?
	contains(missing, "Option --opt expects a string.")?
	jobs = joy_ok!(ctx, ["build", "--jobs", "0"], 1)?
	contains(jobs, "--jobs takes a number")?
	command = joy_ok!(ctx, ["serve"], 2)?
	contains(command, "The subcommand \"serve\" was not recognized.")?
	for asked in [["help", "build"], ["build", "--help"]] {
		help = joy_ok!(ctx, asked, 0)?
		contains(help, "joy build")?
		contains(help, "--out-dir STR")?
		contains(help, "--public-dir STR")?
	}
	listed = joy_ok!(ctx, ["help"], 0)?
	for name in ["dev", "build", "bundles"] {
		contains(listed, "  ${name} ")?
	}
	_ = joy_ok!(ctx, ["help", "serve"], 2)?
	empty = joy_ok!({ ..ctx, dir: "${ctx.dir}/client" }, ["build"], 1)?
	contains(empty, "There are no bundles under client/ and no server/main.roc")
}

# ./joy dev

## A running ./joy dev, and what it has printed so far.
Dev : { child : Cmd.Child, out : Str }

start_dev! : Ctx, List(Str), List((Str, Str)) => Try(Dev, [Failed(Str)])
start_dev! = |ctx, args, envs| {
	child =
		Cmd.new(OsStr.from_str(ctx.joy))
			.args(["dev", "--jobs", "2"].concat(args).map(OsStr.from_str))
			.env(OsStr.from_str("ROC_CACHE_DIR"), OsStr.from_str(ctx.roc_cache))
			.envs(envs.map(|(name, value)| (OsStr.from_str(name), OsStr.from_str(value))))
			.cwd(Path.utf8(ctx.dir))
			.stdin(Null)
			.stdout(Pipe)
			.stderr(MergeWithStdout)
			.spawn_leashed!()
			? |err| Failed("./joy dev did not start: ${Str.inspect(err)}")
	Ok({ child, out: "" })
}

## Read what ./joy dev prints until `count` lines contain `part`.
wait_for! : Dev, Str, U64 => Try(Dev, [Failed(Str)])
wait_for! = |dev, part, count| {
	deadline = Monotonic.now!()
	var $out = dev.out
	while $out.split_on(part).len() - 1 < count {
		if Monotonic.since(Monotonic.now!(), deadline).to_millis() > 120_000 {
			return Err(Failed("./joy dev never printed ${Str.inspect(part)} ${count.to_str()} times:\n${$out}"))
		}
		match read_child!(dev.child, Duration.millis(200)) {
			Ok(Stdout(bytes)) | Ok(Stderr(bytes)) => {
				$out = Str.concat($out, Str.from_utf8_lossy(bytes))
			}
			Err(EndOfInput) => return Err(Failed("./joy dev exited:\n${$out}"))
			Err(_) => {}
		}
	}
	Ok({ ..dev, out: $out })
}

## WORKAROUND: roc-lang/roc#12692. A dev build frees a Child whose method a
## `match` with an early return called, which kills the child. Call
## `child.read!(timeout)` directly when fixed.
read_child! = |child, timeout| child.read!(timeout)

## Ctrl-C, and the output up to the end.
stop_dev! : Dev => Try(Str, [Failed(Str)])
stop_dev! = |dev| {
	pid = dev.child.pid()
	_ = Cmd.new(OsStr.from_str("kill")).args(["-INT", pid.to_str()].map(OsStr.from_str)).run!()
	var $out = dev.out
	var $reading = True
	while $reading {
		match read_child!(dev.child, Duration.seconds(10)) {
			Ok(Stdout(bytes)) | Ok(Stderr(bytes)) => {
				$out = Str.concat($out, Str.from_utf8_lossy(bytes))
			}
			_ => {
				$reading = False
			}
		}
	}
	_ = dev.child.close!()
	Ok($out)
}

## The port in a line ./joy dev printed, after `before`.
port_after : Str, Str -> Try(Str, [Failed(Str)])
port_after = |out, before|
	match out.split_first(before) {
		Ok({ after, .. }) => {
			digits = digits_of(Str.to_utf8(after), [])
			if digits.is_empty() {
				Err(Failed("no port after ${before}"))
			} else {
				Ok(Str.from_utf8(digits) ?? "")
			}
		}
		Err(_) => Err(Failed("./joy dev did not print ${Str.inspect(before)}:\n${out}"))
	}

## The digits at the start of `bytes`, after a colon or spaces.
digits_of : List(U8), List(U8) -> List(U8)
digits_of = |bytes, found|
	match bytes {
		[byte, .. as rest] if found.is_empty() and (byte == ':' or byte == ' ') => digits_of(rest, found)
		[byte, .. as rest] if byte >= '0' and byte <= '9' => digits_of(rest, found.append(byte))
		_ => found
	}

get! : Str => Try(Response, [Failed(Str)])
get! = |url| Http.send!(Request.from_method(GET).with_uri(url), {}).map_err(|err| Failed("GET ${url}: ${Str.inspect(err)}"))

body_of : Response -> Str
body_of = |response| Str.from_utf8_lossy(Response.body(response))

header_of : Response, Str -> Str
header_of = |response, name|
	match Response.headers(response).find_first(|header| header.name.caseless_ascii_equals(name)) {
		Ok(found) => found.value
		Err(_) => ""
	}

## An open event stream and the text it has sent so far.
Events : { response : Http.StreamingResponse, seen : Str }

listen! : Str => Try(Events, [Failed(Str)])
listen! = |port| {
	response =
		Http.send_streaming!(Request.from_method(GET).with_uri("http://localhost:${port}/.joy/events"), { idle_timeout: After(Duration.seconds(90)) })
			? |err| Failed("could not open the event stream: ${Str.inspect(err)}")
	Ok({ response, seen: "" })
}

## Read the stream until it has sent `count` events named `name`.
expect_event! : Events, Str, U64 => Try(Events, [Failed(Str)])
expect_event! = |events, name, count| {
	var $seen = events.seen
	while $seen.split_on("event: ${name}\n").len() - 1 < count {
		match Stream.next!(events.response.chunks()) {
			One({ item: Ok(chunk), .. }) => {
				$seen = Str.concat($seen, Str.from_utf8_lossy(chunk))
			}
			_ => return Err(Failed("the event stream ended before ${count.to_str()} ${name} events:\n${$seen}"))
		}
	}
	Ok({ ..events, seen: $seen })
}

dev_serves_pages! : Ctx => Try({}, [Failed(Str)])
dev_serves_pages! = |ctx| {
	bundle!(ctx, "client/catalog.roc", "catalog")?
	write!(ctx, "public/index.html", "<div data-joy-bundle=\"catalog\"></div><script type=\"module\" src=\"/joy.js\"></script>")?
	write!(ctx, "assets/css/site.css", "body {}")?
	dev = start_dev!(ctx, ["--port", "0"], [])?
	dev1 = wait_for!(dev, "built catalog", 1)?
	port = port_after(dev1.out, "Serving the pages on http://localhost")?
	index = get!("http://localhost:${port}/")?
	contains(body_of(index), "data-joy-bundle=\"catalog\"")?
	check(header_of(index, "cache-control") == "no-cache", "pages are not served with Cache-Control: no-cache")?
	wasm = get!("http://localhost:${port}/catalog/app.wasm")?
	check(Response.status(wasm) == 200 and header_of(wasm, "content-type") == "application/wasm", "the wasm is not served as application/wasm")?
	loader = get!("http://localhost:${port}/joy.js")?
	contains(body_of(loader), "data-joy-bundle")?
	runtime = get!("http://localhost:${port}/runtime.js")?
	contains(body_of(runtime), "const JOY_DEV_PORT = ")?
	css = get!("http://localhost:${port}/css/site.css")?
	check(body_of(css) == "body {}", "assets/ is not served as it is")?
	spa = get!("http://localhost:${port}/books/7")?
	contains(body_of(spa), "data-joy-bundle=\"catalog\"")?
	missing = get!("http://localhost:${port}/missing.wasm")?
	check(Response.status(missing) == 404, "a missing file with an extension is not a 404")?
	assets = read!(ctx, ".joy/dev/assets.json")?
	contains(assets, "\"roots\": { \"joy\": \"client\", \"assets\": \"../../assets\", \"public\": \"../../public\" }")?
	contains(assets, "\"catalog\": \"catalog/app.wasm\"")?
	check(!exists!(ctx, "dist"), "./joy dev wrote dist/")?
	out = stop_dev!(dev1)?
	contains(out, "Stopped")
}

dev_rebuilds! : Ctx => Try({}, [Failed(Str)])
dev_rebuilds! = |ctx| {
	bundle!(ctx, "client/catalog.roc", "catalog")?
	bundle!(ctx, "client/cart.roc", "cart")?
	dev = start_dev!(ctx, ["--port", "0"], [])?
	dev1 = wait_for!(wait_for!(dev, "built catalog", 1)?, "built cart", 1)?
	port = port_after(dev1.out, "Serving the pages on http://localhost")?
	events = expect_event!(listen!(port)?, "hello", 1)?
	bundle!(ctx, "client/catalog.roc", "catalog, edited")?
	dev2 = wait_for!(dev1, "built catalog", 2)?
	events2 = expect_event!(events, "reload", 1)?
	contains(events2.seen, "event: reload\ndata: catalog\n")?
	# A change outside the project's builds rebuilds nothing.
	write!(ctx, "README.md", "notes")?
	write!(ctx, "client/catalog.roc", app_source(platform_from(ctx, "client/catalog.roc"), "\"catalog\"", "", "broken = "))?
	dev3 = wait_for!(dev2, "catalog failed", 1)?
	events3 = expect_event!(events2, "failed", 1)?
	contains(events3.seen, "event: failed\ndata: catalog\ndata: ")?
	ok = get!("http://localhost:${port}/catalog/app.wasm")?
	check(Response.status(ok) == 200, "a failed build took away the last good wasm")?
	bundle!(ctx, "client/catalog.roc", "catalog, fixed")?
	dev4 = wait_for!(dev3, "built catalog", 2)?
	events4 = expect_event!(events3, "fixed", 1)?
	_ = expect_event!(events4, "reload", 2)?
	check(dev4.out.split_on("built cart").len() == 2, "an edit to catalog rebuilt cart:\n${dev4.out}")?
	_ = stop_dev!(dev4)?
	Ok({})
}

dev_shared_module! : Ctx => Try({}, [Failed(Str)])
dev_shared_module! = |ctx| {
	write!(ctx, "client/Shared.roc", "Shared :: [].{\n\tlabel : Str\n\tlabel = \"shared\"\n}\n")?
	write!(ctx, "client/one.roc", app_source(platform_from(ctx, "client/one.roc"), "Shared.label", "import Shared", ""))?
	write!(ctx, "client/two.roc", app_source(platform_from(ctx, "client/two.roc"), "Shared.label", "import Shared", ""))?
	bundle!(ctx, "client/three.roc", "alone")?
	dev = start_dev!(ctx, ["--port", "0"], [])?
	dev1 = wait_for!(wait_for!(wait_for!(dev, "built one", 1)?, "built two", 1)?, "built three", 1)?
	write!(ctx, "client/Shared.roc", "Shared :: [].{\n\tlabel : Str\n\tlabel = \"shared, edited\"\n}\n")?
	dev2 = wait_for!(wait_for!(dev1, "built one", 2)?, "built two", 2)?
	check(dev2.out.split_on("built three").len() == 2, "a change to Shared.roc rebuilt three, which does not import it:\n${dev2.out}")?
	_ = stop_dev!(dev2)?
	Ok({})
}

dev_new_and_removed_bundles! : Ctx => Try({}, [Failed(Str)])
dev_new_and_removed_bundles! = |ctx| {
	bundle!(ctx, "client/first.roc", "first")?
	dev = start_dev!(ctx, ["--port", "0"], [])?
	dev1 = wait_for!(dev, "built first", 1)?
	bundle!(ctx, "client/Later/second.roc", "second")?
	dev2 = wait_for!(dev1, "built Later/second", 1)?
	check(exists!(ctx, ".joy/dev/client/Later/second/app.wasm"), "the new bundle's wasm is missing")?
	assets = read!(ctx, ".joy/dev/assets.json")?
	contains(assets, "\"Later/second\": \"Later/second/app.wasm\"")?
	_ = Path.utf8("${ctx.dir}/client/first.roc").delete!()
	dev3 = wait_for!(dev2, "first is no longer a bundle", 1)?
	check(!exists!(ctx, ".joy/dev/client/first"), "a removed bundle's wasm is still served")?
	_ = stop_dev!(dev3)?
	Ok({})
}

dev_assets! : Ctx => Try({}, [Failed(Str)])
dev_assets! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "public/index.html", "<p>one</p>")?
	write!(ctx, "assets/css/site.css", "body {}")?
	dev = start_dev!(ctx, ["--port", "0"], [])?
	dev1 = wait_for!(dev, "built app", 1)?
	port = port_after(dev1.out, "Serving the pages on http://localhost")?
	events = expect_event!(listen!(port)?, "hello", 1)?
	write!(ctx, "assets/css/site.css", "body { margin: 0 }")?
	events2 = expect_event!(events, "asset", 1)?
	contains(events2.seen, "event: asset\ndata: css/site.css\n")?
	css = get!("http://localhost:${port}/css/site.css")?
	check(body_of(css) == "body { margin: 0 }", "the saved file is not served at once")?
	write!(ctx, "public/index.html", "<p>two</p>")?
	events3 = expect_event!(events2, "asset", 2)?
	contains(events3.seen, "event: asset\ndata: index.html\n")?
	_ = stop_dev!(dev1)?
	Ok({})
}

dev_warning! : Ctx => Try({}, [Failed(Str)])
dev_warning! = |ctx| {
	write!(ctx, "client/app.roc", app_source(platform_from(ctx, "client/app.roc"), "\"app\"", "", "\nhelper = |n| {\n\tunused = 1\n\tn\n}\n"))?
	dev = start_dev!(ctx, ["--port", "0"], [])?
	dev1 = wait_for!(dev, "built app, with warnings", 1)?
	check(exists!(ctx, ".joy/dev/client/app/app.wasm"), "a bundle with a warning was not put in place")?
	_ = stop_dev!(dev1)?
	Ok({})
}

dev_poll! : Ctx => Try({}, [Failed(Str)])
dev_poll! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	dev = start_dev!(ctx, ["--port", "0", "--poll"], [])?
	dev1 = wait_for!(dev, "built app", 1)?
	bundle!(ctx, "client/app.roc", "app, edited")?
	dev2 = wait_for!(dev1, "built app", 2)?
	_ = stop_dev!(dev2)?
	Ok({})
}

dev_next_port! : Ctx => Try({}, [Failed(Str)])
dev_next_port! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	first = start_dev!(ctx, ["--port", "0"], [])?
	first1 = wait_for!(first, "Serving the pages", 1)?
	taken = port_after(first1.out, "Serving the pages on http://localhost")?
	# Another project, so the two do not build into one .joy/.
	other = { ..ctx, dir: "${ctx.dir}/other" }
	bundle!(other, "client/app.roc", "other")?
	second = start_dev!(other, ["--port", taken], [])?
	second1 = wait_for!(second, "Serving the pages", 1)?
	next = port_after(second1.out, "Serving the pages on http://localhost")?
	check(next != taken, "the second ./joy dev claims the taken port ${taken}")?
	_ = stop_dev!(second1)?
	_ = stop_dev!(first1)?
	Ok({})
}

dev_server! : Ctx => Try({}, [Failed(Str)])
dev_server! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "server/main.roc", server_source(ctx, "version one"))?
	dev = start_dev!(ctx, [], [("PORT", "0")])?
	dev1 = wait_for!(dev, "app listening on", 1)?
	contains(dev1.out, "with ${ctx.dir}/.joy/dev/assets.json")?
	dev_port = port_after(dev1.out, "The dev server sends events on http://localhost")?
	app_port = port_after(dev1.out, "[server] app listening on")?
	one = get!("http://localhost:${app_port}/")?
	check(body_of(one) == "version one", "the server answered ${body_of(one)}")?
	page = get!("http://localhost:${dev_port}/")?
	check(Response.status(page) == 404, "the dev server serves pages beside the project's server")?
	events = expect_event!(listen!(dev_port)?, "hello", 1)?
	write!(ctx, "server/main.roc", server_source(ctx, "version two"))?
	dev2 = wait_for!(dev1, "app listening on", 2)?
	events2 = expect_event!(events, "server", 1)?
	contains(events2.seen, "data: server")?
	app_port2 = port_after(dev2.out.split_last("Started server").map_ok(|{ after, .. }| after) ?? dev2.out, "[server] app listening on")?
	two = get!("http://localhost:${app_port2}/")?
	check(body_of(two) == "version two", "the restarted server answered ${body_of(two)}")?
	write!(ctx, "server/main.roc", "${server_source(ctx, "version three")}\nbroken = ")?
	dev3 = wait_for!(dev2, "server failed", 1)?
	still = get!("http://localhost:${app_port2}/")?
	check(body_of(still) == "version two", "a failed server build stopped the running server")?
	remembered = read!(ctx, ".joy/events-port")?
	check(remembered == dev_port, "the dev server's port was not remembered")?
	out = stop_dev!(dev3)?
	contains(out, "Stopped")?
	# The next run asks for the same dev server port first.
	again = start_dev!(ctx, [], [("PORT", "0")])?
	write!(ctx, "server/main.roc", server_source(ctx, "version four"))?
	again1 = wait_for!(again, "The dev server sends events", 1)?
	check(port_after(again1.out, "The dev server sends events on http://localhost")? == dev_port, "the remembered port was not reused")?
	_ = stop_dev!(again1)?
	Ok({})
}

dev_no_server! : Ctx => Try({}, [Failed(Str)])
dev_no_server! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "server/main.roc", server_source(ctx, "never started"))?
	dev = start_dev!(ctx, ["--no-server"], [])?
	dev1 = wait_for!(dev, "built app", 1)?
	lacks(dev1.out, "Started server")?
	lacks(dev1.out, "Serving the pages")?
	port = port_after(dev1.out, "The dev server sends events on http://localhost")?
	events = expect_event!(listen!(port)?, "hello", 1)?
	_ = events
	_ = stop_dev!(dev1)?
	Ok({})
}

dev_ctrl_c! : Ctx => Try({}, [Failed(Str)])
dev_ctrl_c! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "server/main.roc", server_source(ctx, "running"))?
	dev = start_dev!(ctx, [], [("PORT", "0")])?
	dev1 = wait_for!(dev, "app listening on", 1)?
	app_port = port_after(dev1.out, "[server] app listening on")?
	out = stop_dev!(dev1)?
	contains(out, "Stopped")?
	match Http.send!(Request.from_method(GET).with_uri("http://localhost:${app_port}/"), {}) {
		Err(HttpErr(_)) => Ok({})
		other => Err(Failed("the project's server still answers after Ctrl-C: ${Str.inspect(other)}"))
	}
}

## A backend that answers every request with what it got, so a test can see
## what ./joy dev forwarded.
echo_backend! : Str => Try(Server, [Failed(Str)])
echo_backend! = |label|
	Server.start!(
		{ port: 0 },
		|request| {
			host = (Request.headers(request).find_first(|header| header.name.caseless_ascii_equals("host")) ?? { name: "host", value: "none" }).value
			text = "${label} ${Request.method_str(request)} ${Request.uri(request)} host=${host} body=${Str.from_utf8_lossy(Request.body(request))}"
			Ok(Server.respond(Response.from_status(200).with_body(Str.to_utf8(text))))
		},
	)
		.map_err(|err| Failed("the backend did not start: ${Str.inspect(err)}"))

dev_front_door! : Ctx => Try({}, [Failed(Str)])
dev_front_door! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "static/site.css", "body {}")?
	pages = echo_backend!("pages")?
	api = echo_backend!("api")?
	dev = start_dev!(
		ctx,
		[
			"--port",
			"0",
			"--client-url",
			"/static/",
			"--public-dir",
			"static",
			"--proxy",
			"/=http://127.0.0.1:${pages.port().to_str()}",
			"--proxy",
			"/api=http://127.0.0.1:${api.port().to_str()}",
		],
		[],
	)?
	dev1 = wait_for!(dev, "built app", 1)?
	port = port_after(dev1.out, "Serving the pages on http://localhost")?
	page = get!("http://localhost:${port}/books/7?sort=new")?
	contains(body_of(page), "pages GET /books/7?sort=new host=localhost:${port}")?
	posted = Http.send!(Request.from_method(POST).with_uri("http://localhost:${port}/api/books").with_body(Str.to_utf8("title=Dune")), {}) ? |err| Failed("POST: ${Str.inspect(err)}")
	contains(body_of(posted), "api POST /api/books")?
	contains(body_of(posted), "body=title=Dune")?
	wasm = get!("http://localhost:${port}/static/app/app.wasm")?
	check(header_of(wasm, "content-type") == "application/wasm", "the dev build is not served under the client URL")?
	css = get!("http://localhost:${port}/static/site.css")?
	check(body_of(css) == "body {}", "the public folder is not served under the client URL")?
	missing = get!("http://localhost:${port}/static/missing.css")?
	contains(body_of(missing), "pages GET /static/missing.css")?
	events = expect_event!(listen!(port)?, "hello", 1)?
	_ = events
	_ = stop_dev!(dev1)?
	Server.stop!(pages)
	Server.stop!(api)
	Ok({})
}

dev_backend_down! : Ctx => Try({}, [Failed(Str)])
dev_backend_down! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	# A port that was free a moment ago, and nothing listens on now.
	gone = echo_backend!("gone")?
	closed = gone.port().to_str()
	Server.stop!(gone)
	dev = start_dev!(ctx, ["--port", "0", "--proxy", "/=http://127.0.0.1:${closed}"], [])?
	dev1 = wait_for!(dev, "built app", 1)?
	port = port_after(dev1.out, "Serving the pages on http://localhost")?
	answer = get!("http://localhost:${port}/anything")?
	check(Response.status(answer) == 502, "a request for a backend that is down got ${Response.status(answer).to_str()}")?
	contains(body_of(answer), "./joy dev could not reach http://127.0.0.1:${closed}")?
	_ = stop_dev!(dev1)?
	Ok({})
}

dev_bad_proxy! : Ctx => Try({}, [Failed(Str)])
dev_bad_proxy! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	out = joy_ok!(ctx, ["dev", "--proxy", "api=localhost:3000"], 1)?
	contains(out, "--proxy takes PATH=URL")
}

# The generated/ package

## A server on joy-cli-platform that names generated/, reads assets.json
## through `Names`, and prints what it found. With `stay`, it keeps running.
names_server_source : Ctx, Bool -> Str
names_server_source = |_ctx, stay| {
	Str.join_with(
		[
			"app [main!] {",
			"\tpf: platform \"${cli_platform}\",",
			"\tgen: \"../generated/main.roc\",",
			"}",
			"",
			"import pf.Env",
			"import pf.OsStr",
			"import pf.Path",
			"import pf.Sleep",
			"import pf.Stdout",
			"import gen.Asset",
			"import gen.Names",
			"",
			"main! : List(OsStr) => Try({}, _)",
			"main! = |_args| {",
			"\tfile = Env.var_str!(OsStr.from_str(\"JOY_ASSETS_JSON\")) ?? \"dist/assets.json\"",
			"\tfolder =",
			"\t\tmatch file.split_last(\"/\") {",
			"\t\t\tOk({ before, .. }) => before",
			"\t\t\tErr(_) => \".\"",
			"\t\t}",
			"\ttext = Path.utf8(file).read_utf8!()?",
			"\tnames =",
			"\t\tmatch Names.parse(text, folder) {",
			"\t\t\tOk(found) => found",
			"\t\t\tErr(problem) => {",
			"\t\t\t\tStdout.line!(\"refused: \${Str.inspect(problem)}\")?",
			"\t\t\t\treturn Err(Exit(3))",
			"\t\t\t}",
			"\t\t}",
			"\tStdout.line!(\"css \${Asset.path(\"css/site.css\")}\")?",
			"\tStdout.line!(\"joy \${Names.joy(names)}\")?",
			"\tStdout.line!(\"wasm \${Names.wasm(names, App)}\")?",
			"\tStdout.line!(\"url \${Asset.url(\"css/site.css\")}\")?",
			"\tfiles = Names.joy_files(names)",
			"\tStdout.line!(\"loader \${files.loader} app \${(files.wasm)(\"app\")}\")?",
			if (stay) "\t_ = Sleep.millis!(1_000_000_000)" else "",
			"\tOk({})",
			"}",
		],
		"\n",
	)
}

## A bundle that names generated/ and links an asset by its quoted name.
asset_bundle_source : Ctx, Str, Str -> Str
asset_bundle_source = |ctx, file, asset|
	app_source(platform_from(ctx, file), "Asset.path(\"${asset}\")", "import gen.Asset", "")
		.replace_first("\thtml: ", "\tgen: \"../generated/main.roc\",\n\thtml: ")

generated_only_when_named! : Ctx => Try({}, [Failed(Str)])
generated_only_when_named! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "assets/css/site.css", "body {}")?
	_ = joy_ok!(ctx, ["build"], 0)?
	check(!exists!(ctx, "generated"), "generated/ was written though no header names it")?
	write!(ctx, "server/main.roc", names_server_source(ctx, False))?
	bundle!(ctx, "client/Checkout/cart.roc", "cart")?
	write!(ctx, "public/robots.txt", "User-agent: *")?
	_ = joy_ok!(ctx, ["build", "--server-opt", "dev"], 0)?
	for file in ["main.roc", "Bundle.roc", "Asset.roc", "Public.roc", "Names.roc"] {
		check(exists!(ctx, "generated/${file}"), "generated/${file} is missing")?
	}
	bundle_roc = read!(ctx, "generated/Bundle.roc")?
	contains(bundle_roc, "Bundle := [CheckoutCart, App].{")?
	contains(bundle_roc, "CheckoutCart => \"Checkout/cart\"")?
	asset_roc = read!(ctx, "generated/Asset.roc")?
	contains(asset_roc, "(\"css/site.css\", \"css/site.css\"),")?
	public_roc = read!(ctx, "generated/Public.roc")?
	contains(public_roc, "\"robots.txt\",")?
	# The listings are in byte order, so the checked-in package is the same
	# on every machine whatever order the file system lists them in.
	names = ["Z.txt", "a.txt", "b.txt", "b/c.txt", "m.txt", "q.txt", "q/r/s.txt", "x.txt", "y.txt", "z.txt"]
	for name in names {
		write!(ctx, "public/sorted/${name}", name)?
	}
	_ = joy_ok!(ctx, ["build", "--server-opt", "dev"], 0)?
	listed = read!(ctx, "generated/Public.roc")?.split_on("\n").keep_if(|line| line.contains("\"sorted/")).map(|line| line.trim())
	check(listed == names.map(|name| "\"sorted/${name}\","), "public/ is not listed in byte order: ${Str.inspect(listed)}")?
	formatted =
		Cmd.new(OsStr.from_str("roc"))
			.args(["fmt", "--check"].concat(["main.roc", "Bundle.roc", "Asset.roc", "Public.roc", "Names.roc"].map(|file| "generated/${file}")).map(OsStr.from_str))
			.cwd(Path.utf8(ctx.dir))
			.run!()
			? |err| Failed("roc fmt did not run: ${Str.inspect(err)}")
	check(formatted.status == Exited(0), "generated/ is not formatted:\n${Str.from_utf8_lossy(formatted.stdout_bytes)}${Str.from_utf8_lossy(formatted.stderr_bytes)}")
}

generated_build! : Ctx => Try({}, [Failed(Str)])
generated_build! = |ctx| {
	write!(ctx, "client/app.roc", asset_bundle_source(ctx, "client/app.roc", "css/site.css"))?
	write!(ctx, "assets/css/site.css", "body { color: teal }")?
	write!(ctx, "server/main.roc", names_server_source(ctx, False))?
	_ = joy_ok!(ctx, ["build", "--server-opt", "dev", "--client-url", "/static"], 0)?
	json = read!(ctx, "dist/assets.json")?
	css = files_in!(ctx, "dist/client/css").first() ?? "?"
	wasm = wasm_name!(ctx, "app")?
	contains(json, "\"css/site.css\": \"css/${css}\"")?
	# The repository keeps plain names, and the build's copy the hashed ones.
	contains(read!(ctx, "generated/Asset.roc")?, "(\"css/site.css\", \"css/site.css\"),")?
	contains(read!(ctx, "dist/generated/Asset.roc")?, "(\"css/site.css\", \"css/${css}\"),")?
	ran =
		Cmd.new(OsStr.from_str("${ctx.dir}/dist/server/main"))
			.env(OsStr.from_str("JOY_ASSETS_JSON"), OsStr.from_str("${ctx.dir}/dist/assets.json"))
			.cwd(Path.utf8(ctx.dir))
			.run!()
			? |err| Failed("the server did not run: ${Str.inspect(err)}")
	out = Str.from_utf8_lossy(ran.stdout_bytes)
	contains(out, "css css/${css}")?
	contains(out, "url /static/css/${css}")?
	contains(out, "loader /static/joy.")?
	contains(out, "app /static/${wasm}")?
	contains(read!(ctx, "generated/Names.roc")?, "client_url = \"/static/\"")?
	contains(out, "wasm ${wasm}")?
	contains(out, "joy joy.")
}

generated_refuses! : Ctx => Try({}, [Failed(Str)])
generated_refuses! = |ctx| {
	write!(ctx, "client/app.roc", asset_bundle_source(ctx, "client/app.roc", "css/site.css"))?
	write!(ctx, "assets/css/site.css", "body {}")?
	write!(ctx, "server/main.roc", names_server_source(ctx, False))?
	_ = joy_ok!(ctx, ["build", "--server-opt", "dev"], 0)?
	# A server compiled with the build's hashed names, given plain ones.
	write!(ctx, "plain.json", "{ \"roots\": {}, \"joy\": \"joy.js\", \"bundles\": { \"app\": \"app/app.wasm\" }, \"assets\": { \"css/site.css\": \"css/site.css\" }, \"public\": [] }")?
	ran =
		Cmd.new(OsStr.from_str("${ctx.dir}/dist/server/main"))
			.env(OsStr.from_str("JOY_ASSETS_JSON"), OsStr.from_str("${ctx.dir}/plain.json"))
			.cwd(Path.utf8(ctx.dir))
			.run!()
			? |err| Failed("the server did not run: ${Str.inspect(err)}")
	contains(Str.from_utf8_lossy(ran.stdout_bytes), "refused: AssetsDiffer(\"css/site.css\")")?
	write!(ctx, "nobundle.json", "{ \"roots\": {}, \"joy\": \"joy.js\", \"bundles\": {}, \"assets\": {}, \"public\": [] }")?
	missing =
		Cmd.new(OsStr.from_str("${ctx.dir}/dist/server/main"))
			.env(OsStr.from_str("JOY_ASSETS_JSON"), OsStr.from_str("${ctx.dir}/nobundle.json"))
			.cwd(Path.utf8(ctx.dir))
			.run!()
			? |err| Failed("the server did not run: ${Str.inspect(err)}")
	contains(Str.from_utf8_lossy(missing.stdout_bytes), "refused: NoWasm(\"app\")")
}

generated_missing_asset! : Ctx => Try({}, [Failed(Str)])
generated_missing_asset! = |ctx| {
	write!(ctx, "client/app.roc", asset_bundle_source(ctx, "client/app.roc", "css/missing.css"))?
	write!(ctx, "assets/css/site.css", "body {}")?
	out = joy_ok!(ctx, ["build"], 1)?
	contains(out, "There is no file assets/css/missing.css.")
}

generated_same_tag! : Ctx => Try({}, [Failed(Str)])
generated_same_tag! = |ctx| {
	write!(ctx, "client/a_b.roc", asset_bundle_source(ctx, "client/a_b.roc", "x.css"))?
	bundle!(ctx, "client/A/b.roc", "other")?
	write!(ctx, "assets/x.css", "x")?
	out = joy_ok!(ctx, ["build"], 1)?
	contains(out, "would both be AB in generated/Bundle.roc")
}

generated_dev! : Ctx => Try({}, [Failed(Str)])
generated_dev! = |ctx| {
	write!(ctx, "client/app.roc", asset_bundle_source(ctx, "client/app.roc", "css/site.css"))?
	write!(ctx, "assets/css/site.css", "body {}")?
	write!(ctx, "server/main.roc", names_server_source(ctx, True))?
	dev = start_dev!(ctx, [], [])?
	dev1 = wait_for!(dev, "[server] wasm app/app.wasm", 1)?
	contains(dev1.out, "[server] css css/site.css")?
	assets = read!(ctx, ".joy/dev/assets.json")?
	contains(assets, "\"assets\": { \"css/site.css\": \"css/site.css\" }")?
	write!(ctx, "assets/js/new.js", "// new")?
	dev2 = wait_for!(dev1, "Wrote generated/", 2)?
	contains(read!(ctx, "generated/Asset.roc")?, "(\"js/new.js\", \"js/new.js\"),")?
	contains(read!(ctx, ".joy/dev/assets.json")?, "\"js/new.js\": \"js/new.js\"")?
	# The server and the bundle read generated/, so both build again.
	dev3 = wait_for!(wait_for!(dev2, "built server", 2)?, "built app", 2)?
	_ = stop_dev!(dev3)?
	Ok({})
}

dev_watch! : Ctx => Try({}, [Failed(Str)])
dev_watch! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	# A watcher that goes on in a child of its shell, which has to stop too.
	dev = start_dev!(ctx, ["--watch", "echo started $$; sleep 987; echo never", "--watch", "printf 'one\\ntwo\\n'; exit 3"], [])?
	dev1 = wait_for!(dev, "built app", 1)?
	dev2 = wait_for!(dev1, "[echo] started", 1)?
	dev3 = wait_for!(dev2, "[printf] two", 1)?
	dev4 = wait_for!(dev3, "printf exited: Exited(3). ./joy does not start it again.", 1)?
	check(dev4.out.split_on("printf exited").len() == 2, "a finished watcher was reported more than once")?
	_ = stop_dev!(dev4)?
	left = Cmd.new(OsStr.from_str("pgrep")).args(["-f", "sleep 987"].map(OsStr.from_str)).run!() ? |err| Failed("pgrep: ${Str.inspect(err)}")
	check(left.status == Exited(1), "a --watch command outlived ./joy dev:\n${Str.from_utf8_lossy(left.stdout_bytes)}")
}

dev_watch_first_start! : Ctx => Try({}, [Failed(Str)])
dev_watch_first_start! = |ctx| {
	write!(ctx, "client/app.roc", asset_bundle_source(ctx, "client/app.roc", "made.css"))?
	write!(ctx, "assets/other.css", "body {}")?
	# Later than the first build, as a compiler that takes a moment would be.
	dev = start_dev!(ctx, ["--watch", "sleep 3; printf 'p {}' > assets/made.css; sleep 987"], [])?
	dev1 = wait_for!(dev, "app failed", 1)?
	dev2 = wait_for!(dev1, "built app", 1)?
	_ = stop_dev!(dev2)?
	Ok({})
}

build_before! : Ctx => Try({}, [Failed(Str)])
build_before! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	out = joy_ok!(ctx, ["build", "--before", "mkdir -p assets && printf 'p {}' > assets/one.css", "--before", "printf 'a {}' > assets/two.css"], 0)?
	contains(out, "Running mkdir -p assets")?
	names = files_in!(ctx, "dist/client")
	check(names.any(|name| name.starts_with("one.") and name.ends_with(".css")), "the first command's file was not built: ${Str.inspect(names)}")?
	check(names.any(|name| name.starts_with("two.") and name.ends_with(".css")), "the second command's file was not built: ${Str.inspect(names)}")?
	failed = run_joy!(ctx, ["build", "--before", "exit 3", "--before", "printf 'x' > assets/after.css"])?
	check(failed.code != 0, "a failed --before did not fail the build")?
	contains(failed.out, "--before failed, so nothing was built: exit 3")?
	check(!exists!(ctx, "assets/after.css"), "the command after a failed one ran")?
	kept = files_in!(ctx, "dist/client")
	check(kept.any(|name| name.starts_with("one.")), "a failed --before emptied the last build")
}

dev_behind_proxy! : Ctx => Try({}, [Failed(Str)])
dev_behind_proxy! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "public/robots.txt", "User-agent: *")?
	write!(ctx, "server/main.roc", server_source(ctx, "from the server"))?
	api = echo_backend!("api")?
	# No $PORT, so ./joy picks one and starts the server with it.
	dev = start_dev!(
		ctx,
		["--port", "0"],
		[
			("JOY_SERVE_FILES", "1"),
			("JOY_CLIENT_URL", "/static"),
			("JOY_PROXY", "/api=http://127.0.0.1:${api.port().to_str()}"),
		],
	)?
	dev1 = wait_for!(dev, "app listening on", 1)?
	server_port = port_after(dev1.out, "app listening on")?
	contains(dev1.out, "the files under /static/ from the builds, and everything else from the server on ${server_port}")?
	port = port_after(dev1.out, "Serving the pages on http://localhost")?
	page = get!("http://localhost:${port}/books")?
	check(body_of(page) == "from the server", "a page did not come from the project's server: ${body_of(page)}")?
	wasm = get!("http://localhost:${port}/static/app/app.wasm")?
	check(header_of(wasm, "content-type") == "application/wasm", "the dev build is not served under JOY_CLIENT_URL")?
	robots = get!("http://localhost:${port}/static/robots.txt")?
	check(body_of(robots) == "User-agent: *", "public/ is not served under JOY_CLIENT_URL")?
	answered = get!("http://localhost:${port}/api/books")?
	contains(body_of(answered), "api GET /api/books")?
	_ = stop_dev!(dev1)?
	Server.stop!(api)
	Ok({})
}

dev_server_without_files! : Ctx => Try({}, [Failed(Str)])
dev_server_without_files! = |ctx| {
	bundle!(ctx, "client/app.roc", "app")?
	write!(ctx, "server/main.roc", server_answering(ctx, 404, "no such page"))?
	# A port that was free a moment ago, for the project's server.
	probe = echo_backend!("probe")?
	port = probe.port().to_str()
	Server.stop!(probe)
	dev = start_dev!(ctx, [], [("PORT", port)])?
	warned = wait_for!(dev, "answers 404 for /joy.js", 1)?
	contains(warned.out, "The server on ${port} answers 404 for /joy.js, so its pages load without their bundles.")?
	contains(warned.out, "set JOY_SERVE_FILES=1")?
	_ = stop_dev!(warned)?
	Ok({})
}

# ./joy init

init_template! : Ctx => Try({}, [Failed(Str)])
init_template! = |ctx| {
	out = joy_ok!(ctx, ["init", "my-app", "--template", "spa", "--joy-checkout", ctx.joy_root], 0)?
	contains(out, "Started a project from the spa template")?
	contains(out, "    cd my-app\n    ./joy dev")?
	for file in ["client/app.roc", "client/Route.roc", "client/Page/Home.roc", "public/index.html", "assets/css/site.css", "README.md"] {
		check(exists!(ctx, "my-app/${file}"), "init did not write ${file}")?
	}
	ignored = read!(ctx, "my-app/.gitignore")?
	check(ignored == "/joy\n/.joy/\n/dist/\n", "unexpected .gitignore:\n${ignored}")?
	bundle_file = read!(ctx, "my-app/client/app.roc")?
	# The bundle names this checkout's platform from where the project is.
	lacks(bundle_file, "\"../../../../platform/main.roc\"")?
	# The README says how a fresh clone installs ./joy.
	readme = read!(ctx, "my-app/README.md")?
	contains(readme, "    roc run --opt=speed ../")?
	contains(readme, "/cli/main.roc init\n")?
	lacks(readme, "JOY_INSTALL_COMMAND")?
	installed = Path.utf8("${ctx.dir}/my-app/joy")
	check(installed.is_executable!() ?? False, "init did not install an executable ./joy")?
	# The project's own ./joy builds it.
	project = { ..ctx, dir: "${ctx.dir}/my-app", joy: "${ctx.dir}/my-app/joy" }
	built = joy_ok!(project, ["build"], 0)?
	contains(built, "Built 1 bundle")?
	page = read!(project, "dist/client/index.html")?
	contains(page, "data-joy-wasm=\"app/app.")?
	lacks(page, "src=\"/joy.js\"")
}

init_folder_rules! : Ctx => Try({}, [Failed(Str)])
init_folder_rules! = |ctx| {
	write!(ctx, "busy/notes.txt", "mine")?
	refused = joy_ok!(ctx, ["init", "busy", "--template", "spa", "--joy-checkout", ctx.joy_root], 1)?
	contains(refused, "busy has files in it already: notes.txt.")?
	check(!exists!(ctx, "busy/client"), "init wrote into a folder with files")?
	# Dot files do not count, and .gitignore keeps what it had.
	write!(ctx, "dotted/.git/HEAD", "ref: refs/heads/main\n")?
	write!(ctx, "dotted/.gitignore", "node_modules/\n/dist/")?
	_ = joy_ok!(ctx, ["init", "dotted", "--template", "spa", "--joy-checkout", ctx.joy_root], 0)?
	ignored = read!(ctx, "dotted/.gitignore")?
	check(ignored == "node_modules/\n/dist/\n/joy\n/.joy/\n", "unexpected .gitignore:\n${ignored}")?
	unknown = joy_ok!(ctx, ["init", "other", "--template", "nope", "--joy-checkout", ctx.joy_root], 1)?
	contains(unknown, "There is no template called nope. The templates are spa.")?
	check(!exists!(ctx, "other"), "init made a folder for a template it does not have")
}

init_existing_app! : Ctx => Try({}, [Failed(Str)])
init_existing_app! = |ctx| {
	bundle!(ctx, "client/app.roc", "mine")?
	# Installing ./joy beside an app needs no checkout.
	out = joy_with!(ctx, ["init", "--template", "spa"], 0, [("JOY_CHECKOUT", "")])?
	contains(out, "This folder has a Joy app already, so init only installed ./joy.")?
	mine = read!(ctx, "client/app.roc")?
	contains(mine, "\"mine\"")?
	check(exists!(ctx, "joy"), "init did not install ./joy")?
	check(!exists!(ctx, "client/Route.roc"), "init wrote a template over an app")
}

init_no_input! : Ctx => Try({}, [Failed(Str)])
init_no_input! = |ctx| {
	asked = joy_ok!(ctx, ["init", "my-app", "--no-input", "--joy-checkout", ctx.joy_root], 1)?
	contains(asked, "Which template? Name one with --template:\n  spa  ")?
	check(!exists!(ctx, "my-app"), "init made a folder before a template was chosen")?
	no_checkout = joy_with!(ctx, ["init", "my-app", "--template", "spa"], 1, [("JOY_CHECKOUT", "")])?
	contains(no_checkout, "init needs a Joy checkout: --joy-checkout <dir>, or JOY_CHECKOUT.")?
	not_joy = joy_ok!(ctx, ["init", "my-app", "--template", "spa", "--joy-checkout", ctx.dir], 1)?
	contains(not_joy, "is not a Joy checkout")?
	from_env = joy_with!(ctx, ["init", "my-app", "--template", "spa"], 0, [("JOY_CHECKOUT", ctx.joy_root)])?
	contains(from_env, "Started a project from the spa template")
}
