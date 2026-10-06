# Real-browser E2E for the filter while a save is in flight. The controls
# are off while the client waits for the server, but the Back button is the
# browser's: stepping back from /active to / must still show every todo,
# or the list would disagree with the address bar until the next click.
#
# The save is held in the browser by roc-playwright's `with_routes!`, so
# the test looks at the page mid-flight without racing the server. Run via
# ./tests.roc, which starts a server per worker against its own scratch
# database and points E2E_URL here.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.10.0/ELCrvV4MsjnA4phYGXW3oLW2fH9y1imCxPkxhVnpW9jG.tar.zst",
}

import pf.Cmd
import pf.Env
import playwright.Playwright exposing [assert!]

main! = |_args| {
	base = Env.var_str!("E2E_URL") ?? "http://127.0.0.1:8917"

	{ browser, page } = Playwright.launch_page_with!(
		{ new: Cmd.new_str, spawn!: Cmd.spawn_leashed! },
		{ timeout: TimeoutMilliseconds(10000) },
	)?
	page.navigate!("${base}/")?

	# The filters only show once there is a todo.
	page.find(".new-todo").fill!("First")?
	page.key_press!(".new-todo", Enter, [])?
	assert!(page.find_all(".todo-list li").has_count(1))?

	# A filter link pushes /active onto the history, so Back returns to /
	# within the page.
	page.click!(".filters a[href=\"/active\"]")?
	assert!(page.find(".filters a[href=\"/active\"]").has_class("selected"))?

	page.with_routes!([{ pattern: "**/todos", method: POST, action: Hold }], |routed| {
		routed.find(".new-todo").fill!("Held")?
		routed.key_press!(".new-todo", Enter, [])?
		assert!(routed.find(".todoapp").has_class("busy"))?

		_ = routed.evaluate!("(history.back(), 'ok')")?
		assert!(routed.find(".filters a[href=\"/\"]").has_class("selected")) ? |e| BackShouldChangeTheFilterWhileBusy(Str.inspect(e))

		_ = routed.release!(Continue)?
		Ok({})
	})?

	# The save still lands, under the filter the address bar names.
	assert!(page.find(".todoapp").not_has_class("busy"))?
	assert!(page.find_all(".todo-list li").has_count(2))?
	assert!(page.find(".filters a[href=\"/\"]").has_class("selected"))?

	browser.close!()?
	Ok({})
}
