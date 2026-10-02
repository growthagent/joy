# Real-browser E2E for editing a todo. Double-clicking a title must open the
# edit field with the keyboard already in it: the user starts typing at once,
# without a second click to focus the field. Enter commits through the server
# round trip and Escape puts the old title back.
#
# Run via ./e2e.roc, which builds the client, starts a server against a
# scratch database, and points JOY_E2E_URL here.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.27.0/HZanbveSUDoJF8LypR663eH7PpaKEKG36eErEQzmV1Qs.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.10.0/ELCrvV4MsjnA4phYGXW3oLW2fH9y1imCxPkxhVnpW9jG.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.6.0/9ThTkhd7zrviwQpM3LvGd7pvzGhr4ZXNmWJV7pTJc9AJ.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
}

import http.Request
import http.Response
import pf.Cmd
import pf.Env
import pf.Http
import playwright.Playwright exposing [assert!]
import spec.Assert

main! = |_args| {
	base = Env.var_str!("JOY_E2E_URL") ?? "http://127.0.0.1:8917"

	seed!(base, "Edit me")?

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
	assert!(page.find_all(".todo-list li").has_count(1)) ? |e| SeededTodoShouldBeListed(Str.inspect(e))
	# The wasm has booted once the toggle is live (it waits out the save).
	page.find(".toggle").click!()?
	assert!(page.find(".todo-list li").has_class("completed")) ? |e| AppShouldBeInteractive(Str.inspect(e))

	# Double-click opens the editor with the title in it, and the field is
	# focused: what gets typed next lands in it with no further click.
	double_click!(page, ".todo-list li label")?
	assert!(page.find(".todo-list li").has_class("editing")) ? |e| DoubleClickShouldOpenTheEditor(Str.inspect(e))
	assert!(page.find(".edit").has_value("Edit me")) ? |e| EditorShouldStartFromTheTitle(Str.inspect(e))
	Assert.eq(focused_class!(page)?, "edit") ? |e| EditorShouldBeFocused(Str.inspect(e))
	page.key_type_targetless!(" now")?
	assert!(page.find(".edit").has_value("Edit me now")) ? |e| TypingShouldLandInTheEditor(Str.inspect(e))

	# Enter commits: the editor closes and the new title comes back from the
	# server.
	page.key_press_targetless!(Enter, [])?
	assert!(page.find(".todo-list li").not_has_class("editing")) ? |e| EnterShouldCloseTheEditor(Str.inspect(e))
	assert!(page.find(".todo-list li label").has_text("Edit me now")) ? |e| EnterShouldSaveTheTitle(Str.inspect(e))
	assert!(page.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterSave(Str.inspect(e))

	# Escape cancels: the field is focused again on the second edit, and the
	# typed text is thrown away.
	double_click!(page, ".todo-list li label")?
	assert!(page.find(".todo-list li").has_class("editing")) ? |e| SecondDoubleClickShouldOpenTheEditor(Str.inspect(e))
	Assert.eq(focused_class!(page)?, "edit") ? |e| EditorShouldBeFocusedAgain(Str.inspect(e))
	page.key_type_targetless!(" or never")?
	page.key_press_targetless!(Escape, [])?
	assert!(page.find(".todo-list li").not_has_class("editing")) ? |e| EscapeShouldCloseTheEditor(Str.inspect(e))
	assert!(page.find(".todo-list li label").has_text("Edit me now")) ? |e| EscapeShouldKeepTheTitle(Str.inspect(e))

	# The saved title is what the server renders next time.
	page.navigate!("${base}/")?
	assert!(page.find(".todo-list li label").has_text("Edit me now")) ? |e| TitleShouldSurviveAReload(Str.inspect(e))

	browser.close!()?
	Ok({})
}

# A dblclick event on the element, the one the browser synthesises from
# two quick clicks (roc-playwright's mouse cannot count clicks yet).
double_click! = |page, selector|
	page.evaluate!(
		"document.querySelector('${selector}').dispatchEvent(new MouseEvent('dblclick', { bubbles: true })) ? 'sent' : 'cancelled'",
	).map_ok(|_| {})

# The class of the element that has keyboard focus.
focused_class! = |page|
	page.evaluate!("document.activeElement ? document.activeElement.className : 'nothing'")

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
