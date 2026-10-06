# TodoMVC (https://todomvc.com) as a client-side Joy app, with a back-end.
#
# This is joy-todomvc (https://github.com/niclas-ahden/joy-todomvc) plus
# persistence: the server (server/main.roc) passes the stored todos in as
# flags, a JSON string handed to `init`. From there this app owns the UI,
# and the database stays the source of truth: every change goes to the
# server first, the model waits (showing a spinner, see App.view) and then
# adopts the todo list the server answers with. What you see is always what
# is stored, so a refresh can never surprise you.
#
# The model, the messages, and the view live in shared/App.roc, because the
# server renders the same view for the first paint and the client hydrates
# it (see client/www/app.js). What lives here is everything only the client
# does: booting from the flags, reacting to messages, and talking to the API.
app [Model, Msg, init, update, render, subscriptions] {
	pf: platform "../../../platform/main.roc",
	html: "https://github.com/niclas-ahden/joy-html/releases/download/0.17.0/AcmwFzyfbsf5RALWNdX6cXw1cuuDXt96YfcysNqgFqoG.tar.zst",
	shared: "../shared/main.roc",
}

import html.Html
import pf.Console
import pf.DOM
import pf.Effect
import pf.Http
import shared.App
import shared.Todo

Model : App.Model

Msg : App.Msg

render : Model -> Html(Msg)
render = |model| App.view(model)

# React when Back/Forward steps through the history entries the filter
# links push.
subscriptions = |_model| [DOM.on_url_change(|url| BrowserChangedUrl(url))]

# The flags are whatever string the server put in the page: the stored todos
# plus the path the page was requested at. `App.page_model` turns them into
# the same model the server rendered the page from, which is the agreement
# hydration rests on. `Json.parse` figures out the expected shape from how
# the result is used.
init : Str -> (Model, List(Effect(Msg)))
init = |flags|
	match Json.parse(flags) {
		Ok({ todos, filter }) => (App.page_model(todos, filter), [])
		Err(e) => (
			App.page_model([], "/"),
			[Console.log("Could not parse the flags into todos.\nFlags: ${flags}\n\nCause: ${Str.inspect(e)}")],
		)
	}

# One request at a time: a mutation puts the model in the `busy` state and
# nothing but the server's reply (or a purely local message) gets through
# until that reply lands. The view disables the controls while busy, and
# this guard catches whatever the CSS cannot (a focused input's keyboard
# events, a queued click).
update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, msg|
	match msg {
		# The replies land whatever the state. Each carries the complete
		# stored list; the model adopts it and the spinner goes away.
		ServerCreated(result) => {
			(next, effects) = apply_reply(model, result)
			# A stored create also clears the input; a failed one keeps the
			# typed text, so nothing is lost.
			({ ..next, draft: if next.notice.is_empty() "" else next.draft }, effects)
		}

		ServerSaved(result) => apply_reply(model, result)

		other =>
			if model.busy {
				(model, [])
			} else {
				update_idle(model, other)
			}
	}

update_idle : Model, Msg -> (Model, List(Effect(Msg)))
update_idle = |model, msg|
	match msg {
		UserTypedDraft(draft) => ({ ..model, draft: draft }, [])

		UserSubmittedDraft => {
			title = model.draft.trim()
			if title.is_empty() {
				(model, [])
			} else {
				# The draft stays in the input until the server confirms;
				# ServerCreated clears it (see apply_reply's caller).
				(saving(model), [create_todo(title)])
			}
		}

		UserToggledTodo(todo_id, now) =>
			match model.todos.keep_if(|t| t.id == todo_id).first() {
				Ok(todo) => (saving(model), [save_todo({ ..todo, done: now })])
				Err(_) => (model, [])
			}

		UserClickedDestroy(todo_id) => (saving(model), [delete_todo(todo_id)])

		UserToggledAll(now) => (saving(model), [post_json("/toggle-all", Json.to_str({ done: now }))])

		# The filter is purely client-side state; it also lives in the URL,
		# so the page can be refreshed, bookmarked, or stepped back through
		# without losing it.
		UserClickedFilter(filter) => ({ ..model, filter: filter }, [DOM.push_url(App.filter_path(filter))])

		BrowserChangedUrl(url) => ({ ..model, filter: App.filter_from_path(url) }, [])

		UserClickedClearCompleted => (saving(model), [post_json("/clear-completed", "{}")])

		# The edit field is revealed by this render and focused right after
		# it, so typing can start without a second click.
		UserDoubleClickedTodo(todo_id, title) =>
			({ ..model, editing: Editing(todo_id, title) }, [DOM.focus(".todo-list li.editing .edit")])

		UserTypedEdit(edit_text) =>
			match model.editing {
				Editing(todo_id, _) => ({ ..model, editing: Editing(todo_id, edit_text) }, [])
				NotEditing => (model, [])
			}

		# Fired by both Enter and blur. The blur arrives even when Enter got
		# there first (committing rerenders and drops the input), by which
		# time editing is NotEditing and this is a no-op.
		UserCommittedEdit =>
			match model.editing {
				Editing(todo_id, edit_text) => {
					title = edit_text.trim()
					# The row shows its stored title again while the save is in
					# flight; the reply brings the new one.
					closed = { ..model, editing: NotEditing }
					# Committing an emptied-out todo deletes it, per the TodoMVC spec.
					if title.is_empty() {
						(saving(closed), [delete_todo(todo_id)])
					} else {
						match model.todos.keep_if(|t| t.id == todo_id).first() {
							Ok(todo) => (saving(closed), [save_todo({ ..todo, title: title })])
							Err(_) => (closed, [])
						}
					}
				}
				NotEditing => (model, [])
			}

		UserCancelledEdit => ({ ..model, editing: NotEditing }, [])

		# The replies are handled before the busy guard; they cannot get here.
		_ => (model, [])
	}

# A mutation is leaving for the server: show the spinner, and clear the
# notice so a stale failure does not outlive the attempt that follows it.
saving : Model -> Model
saving = |model| { ..model, busy: Bool.True, notice: "" }

# Adopt a mutation's answer. Success replaces the todos with the list the
# server stored. Failure changes nothing except the notice: the model never
# showed the change, so there is nothing to roll back.
apply_reply : Model, Try(App.Response, [HttpErr([Timeout, NetworkError])]) -> (Model, List(Effect(Msg)))
apply_reply = |model, result|
	match result {
		Ok(resp) =>
			if resp.status == 200 {
				match Json.parse(Str.from_utf8_lossy(resp.body)) {
					Ok({ todos }) => ({ ..model, todos: todos, busy: Bool.False, notice: "" }, [])
					Err(e) => (
						{ ..model, busy: Bool.False, notice: "The server's answer made no sense. Refresh to see what it has." },
						[Console.log("Could not decode the todos: ${Str.inspect(e)}")],
					)
				}
			} else {
				(
					{ ..model, busy: Bool.False, notice: "Saving failed (status ${resp.status.to_str()}). The change was not stored." },
					[],
				)
			}

		Err(e) => (
			{ ..model, busy: Bool.False, notice: "Could not reach the server. The change was not stored." },
			[Console.log("Saving failed: ${Str.inspect(e)}")],
		)
	}

# --- Requests to the server (see server/main.roc for the other side) ---

create_todo : Str -> Effect(Msg)
create_todo = |title|
	Http.request(
		{
			..Http.default_request,
			method: POST,
			uri: "/todos",
			headers: [json_header],
			body: Str.to_utf8(Json.to_str({ title: title })),
		},
		|result| ServerCreated(result),
	)

save_todo : Todo.Todo -> Effect(Msg)
save_todo = |todo|
	Http.request(
		{
			..Http.default_request,
			method: PUT,
			uri: "/todos/${todo.id.to_str()}",
			headers: [json_header],
			body: Str.to_utf8(Json.to_str({ title: todo.title, done: todo.done })),
		},
		|result| ServerSaved(result),
	)

delete_todo : I64 -> Effect(Msg)
delete_todo = |todo_id|
	Http.request(
		{ ..Http.default_request, method: DELETE, uri: "/todos/${todo_id.to_str()}" },
		|result| ServerSaved(result),
	)

post_json : Str, Str -> Effect(Msg)
post_json = |uri, body|
	Http.request(
		{ ..Http.default_request, method: POST, uri: uri, headers: [json_header], body: Str.to_utf8(body) },
		|result| ServerSaved(result),
	)

json_header : Http.Header
json_header = { name: "Content-Type", value: "application/json" }
