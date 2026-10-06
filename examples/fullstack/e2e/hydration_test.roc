# Real-browser E2E for the fullstack example, driven through roc-playwright.
#
# The claim it proves end to end: the page arrives server-rendered, the
# client claims that DOM cleanly (window.app.hydration() says so), and the
# claimed page stays interactive with the server round trip intact across a
# reload. The finer grain of the claim walk itself (text splitting, repairs,
# and their warning) is tested in Joy's own suite, in tests/check_hydrate.mjs.
#
# Run via ./e2e.roc, which builds the client, starts the server against a
# scratch database, and points JOY_E2E_URL here. The test seeds its own todos
# through the API, so it assumes nothing about the database beyond that it
# answers, but it does write to it: point JOY_E2E_URL at a server whose data
# you care about and you will find test todos in it.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.10.0/ELCrvV4MsjnA4phYGXW3oLW2fH9y1imCxPkxhVnpW9jG.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.6.0/9ThTkhd7zrviwQpM3LvGd7pvzGhr4ZXNmWJV7pTJc9AJ.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
}

import http.Request
import http.Response
import pf.Cmd
import pf.Env
import pf.Http
import pf.Sleep
import pf.Url
import playwright.Playwright exposing [assert!]
import spec.Assert

main! = |_args| {
	base = Env.var_str!("JOY_E2E_URL") ?? "http://127.0.0.1:8917"

	# Seed through the API so the page has a todo list to server-render.
	seed!(base, "Toggle me")?
	seed!(base, "Stays here")?

	# The server-rendered half needs no browser: the raw HTML already
	# carries the rows and the flags template, before any wasm runs.
	page_html = Http.get_utf8!(Url.parse("${base}/") ? |e| BadBaseUrl(Str.inspect(e)))?
	Assert.contains(page_html, "Toggle me") ? |e| SsrShouldRenderTheTodos(Str.inspect(e))
	Assert.contains(page_html, "joy-model") ? |e| SsrShouldEmbedTheFlags(Str.inspect(e))

	browser_type = match Env.var_str!("JOY_BROWSER") ?? "chromium" {
		"firefox" => Firefox
		"webkit" => WebKit
		_ => Chromium(DefaultChannel)
	}
	{ browser, page } = Playwright.launch_page_with!(
		{ new: Cmd.new_str, spawn!: Cmd.spawn_leashed! },
		{ browser_type, timeout: TimeoutMilliseconds(10000) },
	)?
	page.navigate!("${base}/")?
	assert!(page.find_all(".todo-list li").has_count(2)) ? |e| SeededTodosShouldBeListed(Str.inspect(e))

	# The app booted over that server-rendered DOM and claimed it cleanly:
	# no repairs means every node on the page is a claimed server node.
	outcome = hydration_outcome!(page, 100)?
	Assert.eq(outcome, "{\"claimed\":true,\"mismatch\":null}") ? |e| HydrationWasNotClean(Str.inspect(e))

	# The claimed nodes are live: toggling waits out the server round trip
	# (the model only adopts what the database stored) and lands as the
	# completed class. assert! retries each claim, so no polling here.
	page.find(row(1, " .toggle")).click!()?
	assert!(page.find(row(1, "")).has_class("completed")) ? |e| ToggleShouldComplete(Str.inspect(e))
	assert!(page.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterSave(Str.inspect(e))

	# Adding goes through the same round trip, and the input clears on the
	# server's confirmation.
	page.find(".new-todo").fill!("From the browser test")?
	page.key_press!(".new-todo", Enter, [])?
	assert!(page.find_all(".todo-list li").has_count(3)) ? |e| AddedTodoShouldBeListed(Str.inspect(e))
	assert!(page.find(row(3, " label")).has_text("From the browser test")) ? |e| AddedTodoShouldBeLast(Str.inspect(e))
	assert!(page.find(".new-todo").has_value("")) ? |e| InputShouldClearOnceStored(Str.inspect(e))
	assert!(page.find(".notice").is_hidden()) ? |e| NothingShouldHaveFailed(Str.inspect(e))

	# Full round trip: everything above came back out of SQLite when the
	# server rendered the page again.
	page.navigate!("${base}/")?
	assert!(page.find_all(".todo-list li").has_count(3)) ? |e| TodosShouldSurviveAReload(Str.inspect(e))
	assert!(page.find(row(1, "")).has_class("completed")) ? |e| ToggleShouldSurviveAReload(Str.inspect(e))

	# The filter links hydrate too: click Active, the URL and list follow.
	page.find(".filters a[href=\"/active\"]").click!()?
	assert!(page.has_url("${base}/active")) ? |e| FilterShouldChangeTheUrl(Str.inspect(e))
	assert!(page.find_all(".todo-list li").has_count(2)) ? |e| FilterShouldHideCompleted(Str.inspect(e))

	browser.close!()?
	Ok({})
}

# A todo created through the JSON API, like the client would.
seed! : Str, Str => Try({}, _)
seed! = |base, title| {
	request = Request.from_method(POST)
		.with_uri("${base}/todos")
		.add_header("Content-Type", "application/json")
		.with_body(Str.to_utf8(Json.to_str({ title: title })))
	resp = Http.send!(request)?
	if Response.status(resp) == 200 {
		Ok({})
	} else {
		Err(SeedingFailed(title, Response.status(resp)))
	}
}

# The app handle's hydration() report, once the wasm has booted and set
# window.app. Polled here because the boot is the very thing awaited: no
# element can prove it (a hydrated page looks the same before and after).
hydration_outcome! = |page, attempts_left| {
	outcome = page.evaluate!(
		"window.app && window.app.hydration() ? JSON.stringify(window.app.hydration()) : 'pending'",
	) ?? "pending"
	if outcome != "pending" {
		Ok(outcome)
	} else if attempts_left == 0 {
		Err(AppNeverBooted)
	} else {
		Sleep.millis!(100)
		hydration_outcome!(page, attempts_left - 1)
	}
}

# Selector for the nth (1-based) todo row, with an optional suffix inside it.
row : U64, Str -> Str
row = |n, suffix| ".todo-list li:nth-child(${n.to_str()})${suffix}"
