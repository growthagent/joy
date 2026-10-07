# Real-browser E2E for the page without its wasm: the todos must be readable
# and the filter links must work as plain links, because the server rendered
# all of it. Server-side rendering is a promise about the worst case (a slow
# or dead connection after the HTML arrived, an old browser, a broken build),
# and this is that case: roc-playwright's `with_routes!` aborts the request
# for app.wasm before it leaves the browser, so the app never boots and the
# page is whatever the server sent.
#
# Run via ./tests.roc, which starts a server per worker against its own
# scratch database and points E2E_URL here.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.11.1/GJz6pEptEAmK2FqGnzJQUhF9cymdiV3vwETDdCDevAZ1.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.6.1/55UFmX5Ye5dNxWYzbzxQfsE54KTNwaoHNmYan163HbzB.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
}

import http.Request
import http.Response
import pf.Cmd
import pf.Env
import pf.Http
import pf.Sleep
import playwright.Playwright exposing [assert!]
import spec.Assert

main! = |_args| {
	base = Env.var_str!("E2E_URL") ?? "http://127.0.0.1:8917"

	# One done and one active todo, so the filters have something to tell
	# apart. Toggle-all runs while only the first exists.
	post_json!(base, "/todos", { title: "Already done" })?
	post_json!(base, "/toggle-all", { done: Bool.True })?
	post_json!(base, "/todos", { title: "Still active" })?

	{ browser, page } = Playwright.launch_page_with!(
		{ new: Cmd.new_str, spawn!: Cmd.spawn_leashed! },
		{ timeout: TimeoutMilliseconds(10000) },
	)?

	# Only the wasm is dropped. The page, the stylesheet, the loader, and
	# the runtime all still arrive, so the loader runs and fails at the
	# fetch, which is where a dead connection would fail it too.
	no_wasm = [{ pattern: "**/app.wasm", method: GET, action: Abort(Failed) }]
	page.with_routes!(no_wasm, |routed| {
		routed.navigate!("${base}/")?

		# The list is on the page because the server put it there.
		assert!(routed.find_all(".todo-list li").has_count(2)) ? |e| SsrShouldListTheTodos(Str.inspect(e))
		assert!(routed.find(row(1, "")).has_class("completed")) ? |e| SsrShouldMarkTheDoneOne(Str.inspect(e))
		assert!(routed.find(row(2, " label")).has_text("Still active")) ? |e| SsrShouldRenderTheTitles(Str.inspect(e))
		assert!(routed.find(".todo-count").has_text("1 item left")) ? |e| SsrShouldCountTheActiveOnes(Str.inspect(e))

		# And the app really never boots: the loader only sets window.app
		# once mount resolves, and the wasm fetch it awaits was aborted. A
		# boot against a local server takes well under a second, so still
		# nothing after one is the wasm never arriving, not a slow start.
		still_unbooted!(routed, 10)?

		# The filters are real links to pages the server renders filtered,
		# so they work with no script at all: the click is a navigation,
		# and the page that comes back has only the active todo.
		routed.find(".filters a[href=\"/active\"]").click!()?
		assert!(routed.has_url("${base}/active")) ? |e| FilterLinkShouldNavigate(Str.inspect(e))
		assert!(routed.find_all(".todo-list li").has_count(1)) ? |e| ServerShouldRenderTheFilteredList(Str.inspect(e))
		assert!(routed.find(row(1, " label")).has_text("Still active")) ? |e| ServerShouldKeepTheActiveOne(Str.inspect(e))
		assert!(routed.find(".filters a[href=\"/active\"]").has_class("selected")) ? |e| ServerShouldSelectTheFilter(Str.inspect(e))
		Ok({})
	})?

	# With the wasm back, the same page boots and is live again: the toggle
	# waits out the server round trip and lands.
	page.navigate!("${base}/")?
	page.find(row(2, " .toggle")).click!()?
	assert!(page.find(row(2, "")).has_class("completed")) ? |e| AppShouldBootOnceTheWasmArrives(Str.inspect(e))
	assert!(page.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterSave(Str.inspect(e))

	browser.close!()?
	Ok({})
}

# Fails as soon as the app has booted, checking every 100ms for as many
# attempts as given. Before the boot `window.app` is the #app element (a
# window names its elements by id), so the app handle is told apart by its
# hydration() function.
still_unbooted! = |page, attempts_left| {
	state = page.evaluate!("window.app && typeof window.app.hydration === 'function' ? 'booted' : 'not booted'")?
	Assert.eq(state, "not booted") ? |e| AppShouldNotHaveBooted(Str.inspect(e))
	if attempts_left == 0 {
		Ok({})
	} else {
		Sleep.millis!(100)
		still_unbooted!(page, attempts_left - 1)
	}
}

# Selector for the nth (1-based) todo row, with an optional suffix inside it.
row : U64, Str -> Str
row = |n, suffix| ".todo-list li:nth-child(${n.to_str()})${suffix}"

# A JSON POST to the server under test, failing on any non-200 answer.
post_json! : Str, Str, _ => Try({}, _)
post_json! = |base, api_path, value| {
	request = Request.from_method(POST)
		.with_uri("${base}${api_path}")
		.add_header("Content-Type", "application/json")
		.with_body(Str.to_utf8(Json.to_str(value)))
	resp = Http.send!(request)?
	if Response.status(resp) == 200 {
		Ok({})
	} else {
		Err(RequestFailed(api_path, Response.status(resp)))
	}
}
