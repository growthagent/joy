# Real-browser E2E for the failure paths: when a save fails, the page must
# show a notice, keep what was typed, and change nothing else, because the
# model only ever adopts what the database confirmed. Three ways a save can
# fail, each with its own notice:
#
#   - the server refuses it (a non-200 status),
#   - the server cannot be reached (the request itself fails),
#   - the server answers 200 with a body that is not the todo list.
#
# And a failure must not outlive the next attempt: with only one route
# broken, a save that gets through clears the notice the failed one left.
#
# The failures are staged in the browser: roc-playwright's `with_routes!`
# answers the client's requests before they leave the page (`Fulfill` with
# a response of our choosing, `Abort` for a dropped connection), so the
# server needs no test hooks and never sees them. Run via ./e2e.roc, which
# starts a server per worker against its own scratch database and points
# JOY_E2E_URL here.
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

main! = |_args| {
	base = Env.var_str!("JOY_E2E_URL") ?? "http://127.0.0.1:8917"

	post_json!(base, "/todos", { title: "Survivor" })?

	{ browser, page } = Playwright.launch_page_with!(
		{ new: Cmd.new_str, spawn!: Cmd.spawn_leashed! },
		{ timeout: TimeoutMilliseconds(10000) },
	)?
	page.navigate!("${base}/")?
	assert!(page.find_all(".todo-list li").has_count(1)) ? |e| SeededTodoShouldBeListed(Str.inspect(e))

	# Every mutation the client makes goes to one of these.
	api = ["**/todos", "**/todos/*", "**/toggle-all", "**/clear-completed"]

	# --- Refused: the server answers with a 500 ---
	refused = Fulfill({ status: 500, headers: [{ name: "content-type", value: "text/plain" }], body: Str.to_utf8("This save was refused on purpose") })
	page.with_routes!(rules(api, refused), |routed| {
		# A create that fails: the notice appears, the list does not grow,
		# and the typed title stays in the input so nothing is lost.
		routed.find(".new-todo").fill!("Doomed")?
		routed.key_press!(".new-todo", Enter, [])?
		assert!(routed.find(".notice").has_text("Saving failed (status 500). The change was not stored.")) ? |e| FailureShouldShowTheNotice(Str.inspect(e))
		assert!(routed.find_all(".todo-list li").has_count(1)) ? |e| NothingShouldBeAdded(Str.inspect(e))
		assert!(routed.find(".new-todo").has_value("Doomed")) ? |e| DraftShouldSurviveTheFailure(Str.inspect(e))
		assert!(routed.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterFailure(Str.inspect(e))

		# A toggle that fails: same notice, and the row stays as stored.
		# The model never showed the change, so there is nothing to roll
		# back.
		routed.find(".todo-list li .toggle").click!()?
		assert!(routed.find(".notice").has_text("Saving failed (status 500). The change was not stored.")) ? |e| FailedToggleShouldShowTheNotice(Str.inspect(e))
		assert!(routed.find(".todo-list li").not_has_class("completed")) ? |e| FailedToggleShouldChangeNothing(Str.inspect(e))
		# busy goes up synchronously on the click and only comes down with
		# the reply, so this outwaits the round trip: the next action must
		# not race a still-busy model, whose guard would drop the event.
		assert!(routed.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterFailedToggle(Str.inspect(e))
		Ok({})
	})?

	# --- Unreachable: the request never completes ---
	# An aborted request rejects the fetch, which the client reports as a
	# network error rather than a status.
	page.with_routes!(rules(api, Abort(Failed)), |routed| {
		# A delete that fails: the row is still there. The destroy button
		# only shows on hover, so hover first like a user would.
		routed.find(".todo-list li").hover!()?
		routed.find(".todo-list li .destroy").click!()?
		assert!(routed.find(".notice").has_text("Could not reach the server. The change was not stored.")) ? |e| UnreachableShouldShowTheNotice(Str.inspect(e))
		assert!(routed.find_all(".todo-list li").has_count(1)) ? |e| FailedDeleteShouldKeepTheRow(Str.inspect(e))
		assert!(routed.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterFailedDelete(Str.inspect(e))

		# An edit that fails: the editor closes when Enter commits, and
		# with the save lost the row keeps the stored title.
		double_click!(routed, ".todo-list li label")?
		assert!(routed.find(".todo-list li").has_class("editing")) ? |e| DoubleClickShouldOpenTheEditor(Str.inspect(e))
		routed.key_type_targetless!(" renamed")?
		routed.key_press_targetless!(Enter, [])?
		assert!(routed.find(".notice").has_text("Could not reach the server. The change was not stored.")) ? |e| FailedEditShouldShowTheNotice(Str.inspect(e))
		assert!(routed.find(".todo-list li").not_has_class("editing")) ? |e| FailedEditShouldCloseTheEditor(Str.inspect(e))
		assert!(routed.find(".todo-list li label").has_text("Survivor")) ? |e| FailedEditShouldKeepTheTitle(Str.inspect(e))
		assert!(routed.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterFailedEdit(Str.inspect(e))
		Ok({})
	})?

	# --- Nonsense: a 200 whose body is not the todo list ---
	# The client trusts nothing it cannot decode, so this is a failure
	# too, with a notice that says to refresh.
	nonsense = Fulfill({ status: 200, headers: [{ name: "content-type", value: "application/json" }], body: Str.to_utf8("{\"todos\": \"not a list\"}") })
	page.with_routes!(rules(api, nonsense), |routed| {
		# The toggle-all checkbox is invisible behind its label.
		routed.find("label[for=toggle-all]").click!()?
		assert!(routed.find(".notice").has_text("The server's answer made no sense. Refresh to see what it has.")) ? |e| NonsenseShouldShowTheNotice(Str.inspect(e))
		assert!(routed.find(".todo-list li").not_has_class("completed")) ? |e| NonsenseShouldChangeNothing(Str.inspect(e))
		assert!(routed.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterNonsense(Str.inspect(e))
		Ok({})
	})?

	# --- Partly broken: only the deletes fail, everything else gets through ---
	# Rules match the method too, so one resource can be broken for one
	# verb while the others still reach the server. The failed delete
	# leaves its notice, and the toggle that follows is stored and takes
	# the notice with it: a failure never outlives the next attempt.
	no_deletes = [{ pattern: "**/todos/*", method: DELETE, action: Abort(Failed) }]
	page.with_routes!(no_deletes, |routed| {
		routed.find(".todo-list li").hover!()?
		routed.find(".todo-list li .destroy").click!()?
		assert!(routed.find(".notice").has_text("Could not reach the server. The change was not stored.")) ? |e| BrokenDeleteShouldShowTheNotice(Str.inspect(e))
		assert!(routed.find_all(".todo-list li").has_count(1)) ? |e| BrokenDeleteShouldKeepTheRow(Str.inspect(e))
		assert!(routed.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterBrokenDelete(Str.inspect(e))

		# Same URL, different method: the PUT is not matched and lands.
		routed.find(".todo-list li .toggle").click!()?
		assert!(routed.find(".todo-list li").has_class("completed")) ? |e| ToggleShouldGetThroughTheBrokenDeletes(Str.inspect(e))
		assert!(routed.find(".notice").is_hidden()) ? |e| StoredToggleShouldClearTheNotice(Str.inspect(e))
		assert!(routed.find(".todoapp").not_has_class("busy")) ? |e| SpinnerShouldStopAfterStoredToggle(Str.inspect(e))
		Ok({})
	})?

	# Back to normal: with every block over the very next attempt reaches
	# the server and succeeds. The draft typed under the first block is
	# still in the input.
	assert!(page.find(".new-todo").has_value("Doomed")) ? |e| DraftShouldSurviveEveryFailure(Str.inspect(e))
	page.key_press!(".new-todo", Enter, [])?
	assert!(page.find_all(".todo-list li").has_count(2)) ? |e| RetryShouldStoreTheTodo(Str.inspect(e))
	assert!(page.find(".new-todo").has_value("")) ? |e| InputShouldClearOnceStored(Str.inspect(e))
	assert!(page.find(".notice").is_hidden()) ? |e| NoticeShouldStayClearOnSuccess(Str.inspect(e))

	# The server never saw any of the failed saves. The one toggle that got
	# through is the only change it stored.
	page.navigate!("${base}/")?
	assert!(page.find_all(".todo-list li").has_count(2)) ? |e| OnlyTheStoredTodosShouldSurviveAReload(Str.inspect(e))
	assert!(page.find_all(".todo-list li.completed").has_count(1)) ? |e| OnlyTheStoredToggleShouldSurviveAReload(Str.inspect(e))
	assert!(page.find(".todo-list li:nth-child(1)").has_class("completed")) ? |e| TheStoredToggleShouldBeTheSurvivor(Str.inspect(e))

	browser.close!()?
	Ok({})
}

# The same action for every pattern, whatever the method.
rules = |patterns, action| patterns.map(|pattern| { pattern, method: AnyMethod, action })

# A dblclick event on the element, the one the browser synthesises from
# two quick clicks (roc-playwright's mouse cannot count clicks yet).
double_click! = |page, selector|
	page.evaluate!(
		"document.querySelector('${selector}').dispatchEvent(new MouseEvent('dblclick', { bubbles: true })) ? 'sent' : 'cancelled'",
	).map_ok(|_| {})

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
