# Real-browser E2E for a page whose flags the client cannot read. The
# server puts the todos in the page twice: as markup, and as JSON in the
# flags template the client boots from. When the JSON is not what `init`
# expects (a server bug, a proxy that mangled the page, an old cached
# copy), the client must still come up, on an empty model, and hydration
# must repair the markup to match it rather than leave rows on screen that
# the model does not know about. The next save then brings the stored list
# back from the server, so the page recovers on its own.
#
# The broken page is staged in the browser: roc-playwright's `with_routes!`
# answers the document request with the server's real page, flags swapped
# for garbage, so the server needs no test hooks and every other request
# (assets, the API) reaches it as usual. Run via ./tests.roc, which starts a
# server per worker against its own scratch database and points
# E2E_URL here.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.13.1/AWahhV9oKjtqpZNTG5mUK5i86Fy1Lwssrg6yeDG52Bvy.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.7.0/BGjQKbG9U3V8cH6mRbypUAFVqFoVEu6n9bsA3QmFL1f4.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
}

import http.Request
import http.Response
import pf.Cmd
import pf.OsStr
import pf.Duration
import pf.Env
import pf.Http
import pf.Sleep
import playwright.Playwright exposing [assert!]
import spec.Assert

main! = |_args| {
	base = Env.var_str!("E2E_URL") ?? "http://127.0.0.1:8917"

	post_json!(base, "/todos", { title: "Stored before the page broke" })?

	# The server's own page, with the flags replaced by something that is
	# not JSON. The markup still lists the seeded todo.
	served = Http.send!(Request.from_method(GET).with_uri("${base}/"), {})?
	page_html = Str.from_utf8(Response.body(served)) ? |_| PageNotUtf8
	broken_html = with_flags(page_html, "this is not the todo list")?
	Assert.contains(broken_html, "Stored before the page broke") ? |e| SsrShouldStillRenderTheTodos(Str.inspect(e))

	{ browser, page } = Playwright.launch_page_with!(
		{ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis },
		{ timeout: TimeoutMilliseconds(10000) },
	)?

	# Only the document is swapped: the pattern is the exact page URL, so
	# the assets and the API still reach the server.
	broken_page = Fulfill({
		status: 200,
		headers: [{ name: "content-type", value: "text/html; charset=utf-8" }],
		body: Str.to_utf8(broken_html),
	})
	page.with_routes!([{ pattern: "${base}/", method: GET, action: broken_page }], |routed| {
		routed.navigate!("${base}/")?

		# The app booted, and its first render disagreed with the markup:
		# an empty model has no list, the page had one. Hydration reports
		# the mismatch and rebuilds, so the row the model never knew about
		# is gone. The empty list also means the main section and footer
		# are gone, per the TodoMVC spec.
		Assert.eq(hydration_result!(routed, 100)?, "mismatch") ? |e| HydrationShouldReportTheMismatch(Str.inspect(e))
		assert!(routed.find_all(".todo-list li").has_count(0)) ? |e| RepairShouldDropTheUnknownRow(Str.inspect(e))
		assert!(routed.find(".main").is_hidden()) ? |e| RepairShouldMatchTheEmptyModel(Str.inspect(e))
		assert!(routed.find(".notice").is_hidden()) ? |e| BadFlagsShouldNotShowASavingNotice(Str.inspect(e))
		Ok({})
	})?

	# The page is live on its empty model. The first save answers with the
	# whole stored list, so the seeded todo comes back along with the new
	# one: the client is in sync with the database again.
	page.find(".new-todo").fill!("Saved after the page broke")?
	page.key_press!(".new-todo", Enter, [])?
	assert!(page.find_all(".todo-list li").has_count(2)) ? |e| FirstSaveShouldResyncTheList(Str.inspect(e))
	assert!(page.find(row(1, " label")).has_text("Stored before the page broke")) ? |e| ResyncShouldBringTheStoredTodoBack(Str.inspect(e))
	assert!(page.find(row(2, " label")).has_text("Saved after the page broke")) ? |e| ResyncShouldIncludeTheNewTodo(Str.inspect(e))
	assert!(page.find(".new-todo").has_value("")) ? |e| InputShouldClearOnceStored(Str.inspect(e))
	assert!(page.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterSave(Str.inspect(e))

	# A reload gets the real page, and both todos are in it.
	page.navigate!("${base}/")?
	assert!(page.find_all(".todo-list li").has_count(2)) ? |e| BothTodosShouldSurviveAReload(Str.inspect(e))

	browser.close!()?
	Ok({})
}

# The page with the flags template's content replaced.
with_flags : Str, Str -> Try(Str, [FlagsTemplateNotFound])
with_flags = |page_html, flags| {
	opening = "id=\"joy-model\">"
	at_template = page_html.split_first(opening).map_err(|_| FlagsTemplateNotFound)?
	at_close = at_template.after.split_first("</template>").map_err(|_| FlagsTemplateNotFound)?
	Ok("${at_template.before}${opening}${flags}</template>${at_close.after}")
}

# Whether the app's hydration walk was clean or had to repair, once the
# wasm has booted and set window.app. Polled because the boot is the very
# thing awaited: no element can prove it, a hydrated page looks the same
# before and after.
hydration_result! = |page, attempts_left| {
	result = page.evaluate!(
		"window.app && window.app.hydration() ? (window.app.hydration().mismatch === null ? 'clean' : 'mismatch') : 'pending'",
	) ?? "pending"
	if result != "pending" {
		Ok(result)
	} else if attempts_left == 0 {
		Err(AppNeverBooted)
	} else {
		Sleep.millis!(100)?
		hydration_result!(page, attempts_left - 1)
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
	resp = Http.send!(request, {})?
	if Response.status(resp) == 200 {
		Ok({})
	} else {
		Err(RequestFailed(api_path, Response.status(resp)))
	}
}
