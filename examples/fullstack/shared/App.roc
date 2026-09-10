## The TodoMVC application core both sides import: the model, the messages,
## and the whole view. The view lives here because of hydration: the server
## renders the page with this exact view, and the client's first render then
## claims that markup node for node instead of rebuilding it, which only
## works when both sides produce the markup from the same code.
##
## What stays out is just as deliberate: `update` and the effects are
## client-only (they speak to Joy's platform), and the SQL is server-only.
## This module is pure data and pure views, so both apps can compile it.
import Todo
import html.Html exposing [Html, a, button, div, footer, h1, header, input, label, li, p, section, span, strong, text, ul]
import html.Attribute exposing [autofocus, checked, class, class_list, for_, href, id, on, on_check, on_click, on_input, on_key, placeholder, type, value]

App := [].{
	Filter : [All, Active, Completed]

	## Which todo is being edited, if any, and the text typed so far. The
	## todo's own title only changes when the edit commits, so Escape can
	## throw the draft away.
	Edit : [NotEditing, Editing(I64, Str)]

	Model : {
		todos : List(Todo.Todo),
		draft : Str,
		filter : Filter,
		editing : Edit,

		## True while a change is on its way to the server. The todos only
		## change when the server's answer comes back (see client/main.roc),
		## so the view shows a spinner and ignores further input until then:
		## what you see is always what the database holds.
		busy : Bool,

		## A saving failure, shown under the list until the next attempt.
		notice : Str,
	}

	## Structurally identical to the Joy platform's `Http.Response`. Spelled
	## out here because the server app imports this package too and has no
	## Joy platform to name the type from; records are structural, so the
	## client's Http effects unify with this alias anyway.
	Response : { status : U16, headers : List({ name : Str, value : Str }), body : List(U8) }

	Msg : [
		UserTypedDraft(Str),
		UserSubmittedDraft,
		# Every mutation answers with the complete stored todo list, and the
		# model adopts it wholesale. ServerCreated additionally clears the
		# draft, which is why the two replies are distinct.
		ServerCreated(Try(Response, [HttpErr([Timeout, NetworkError])])),
		UserToggledTodo(I64, Bool),
		UserClickedDestroy(I64),
		UserToggledAll(Bool),
		UserClickedFilter(Filter),
		UserClickedClearCompleted,
		UserDoubleClickedTodo(I64, Str),
		UserTypedEdit(Str),
		UserCommittedEdit,
		UserCancelledEdit,
		ServerSaved(Try(Response, [HttpErr([Timeout, NetworkError])])),
		BrowserChangedUrl(Str),
	]

	## The model as it stands when a page arrives: the stored todos, the
	## filter the path names, nothing typed and nothing being edited. The
	## server renders the page from this and the client boots from it, which
	## is the agreement hydration rests on: same todos and path in, same
	## markup out.
	page_model : List(Todo.Todo), Str -> Model
	page_model = |todos, path|
		{ todos, draft: "", filter: App.filter_from_path(path), editing: NotEditing, busy: Bool.False, notice: "" }

	## The filter's place in the URL: the server serves the page on all three
	## paths and puts the path into the flags, so these two functions are the
	## whole contract.
	filter_path : Filter -> Str
	filter_path = |filter|
		match filter {
			All => "/"
			Active => "/active"
			Completed => "/completed"
		}

	filter_from_path : Str -> Filter
	filter_from_path = |path|
		match path {
			"/active" => Active
			"/completed" => Completed
			_ => All
		}

	view : Model -> Html(Msg)
	view = |model| {
		visible = match model.filter {
			All => model.todos
			Active => model.todos.keep_if(|t| !t.done)
			Completed => model.todos.keep_if(|t| t.done)
		}

		# The list section and footer only exist while there are todos,
		# per the TodoMVC spec.
		body = if model.todos.is_empty() {
			[]
		} else {
			[App.view_main(model, visible), App.view_footer(model)]
		}

		div(
			[],
			[
				# The `busy` class shows the spinner and turns off pointer
				# events (see style.css) while a change is saving. Update
				# ignores user messages in that state too, so the keyboard
				# cannot slip a second request past the CSS.
				section(
					[class_list([("todoapp", Bool.True), ("busy", model.busy)])],
					[App.view_header(model)].concat(body),
				),
				# Always rendered so every render has the same structure;
				# CSS hides it while it is empty.
				p([class("notice")], [text(model.notice)]),
				footer(
					[class("info")],
					[p([], [text("Double-click to edit a todo")])],
				),
			],
		)
	}

	view_header : Model -> Html(Msg)
	view_header = |model|
		header(
			[class("header")],
			[
				h1([], [text("todos")]),
				input([
					class("new-todo"),
					placeholder("What needs to be done?"),
					autofocus(Bool.True),
					value(model.draft),
					on_input(|s| UserTypedDraft(s)),
					on_key("keydown", ["Enter"], |_| UserSubmittedDraft),
				]),
			],
		)

	view_main : Model, List(Todo.Todo) -> Html(Msg)
	view_main = |model, visible| {
		all_done = model.todos.count_if(|t| !t.done) == 0
		section(
			[class("main")],
			[
				input([
					id("toggle-all"),
					class("toggle-all"),
					type("checkbox"),
					checked(all_done),
					on_check(|now| UserToggledAll(now)),
				]),
				label([for_("toggle-all")], [text("Mark all as complete")]),
				ul([class("todo-list")], visible.map(|t| App.view_todo(t, model.editing))),
			],
		)
	}

	view_todo : Todo.Todo, Edit -> Html(Msg)
	view_todo = |todo, editing| {
		(is_editing, edit_text) = match editing {
			Editing(todo_id, typed) => (todo_id == todo.id, typed)
			NotEditing => (Bool.False, "")
		}

		# Both the view row and the edit input are always rendered, and CSS shows
		# one or the other based on the li's `editing` class. That keeps every render's
		# structure identical, so that we only ever patch attributes and text.
		#
		# While the input is hidden its `value` tracks the todo's title, so each
		# edit starts from the current title. While editing it tracks the typed
		# text, so cancelling can put the title back.
		shown_value = if is_editing edit_text else todo.title

		li(
			[
				class_list([("completed", todo.done), ("editing", is_editing)]),
			],
			[
				div(
					[class("view")],
					[
						input([
							class("toggle"),
							type("checkbox"),
							checked(todo.done),
							on_check(|now| UserToggledTodo(todo.id, now)),
						]),
						label(
							[on("dblclick", UserDoubleClickedTodo(todo.id, todo.title))],
							[text(todo.title)],
						),
						button([class("destroy"), on_click(UserClickedDestroy(todo.id))], []),
					],
				),
				input([
					class("edit"),
					value(shown_value),
					on_input(|s| UserTypedEdit(s)),
					# Fires when editing ends however it ends, because hiding
					# the input drops its focus. By then a commit or cancel
					# has already cleared `editing`, so the commit below is a
					# no-op unless focus genuinely moved away mid-edit.
					on("blur", UserCommittedEdit),
					on_key(
						"keydown",
						["Enter", "Escape"],
						|e| if e.key == "Enter" UserCommittedEdit else UserCancelledEdit,
					),
				]),
			],
		)
	}

	view_footer : Model -> Html(Msg)
	view_footer = |model| {
		active_count = model.todos.count_if(|t| !t.done)
		completed_count = model.todos.len() - active_count
		items = if active_count == 1 "item" else "items"

		clear = if completed_count == 0 {
			[]
		} else {
			[button([class("clear-completed"), on_click(UserClickedClearCompleted)], [text("Clear completed")])]
		}

		footer(
			[class("footer")],
			[
				span(
					[class("todo-count")],
					[strong([], [text(active_count.to_str())]), text(" ${items} left")],
				),
				ul(
					[class("filters")],
					[
						App.view_filter("All", All, model.filter),
						App.view_filter("Active", Active, model.filter),
						App.view_filter("Completed", Completed, model.filter),
					],
				),
			].concat(clear),
		)
	}

	# A real link, so open-in-new-tab and copy-link work (the server serves the
	# page on every filter path). A normal click stays client-side:
	# `prevent_default` stops the navigation and the msg swaps the filter.
	view_filter : Str, Filter, Filter -> Html(Msg)
	view_filter = |label_text, filter, current|
		li(
			[],
			[
				a(
					[
						href(App.filter_path(filter)),
						class_list([("selected", filter == current)]),
						on_click(UserClickedFilter(filter)).prevent_default(),
					],
					[text(label_text)],
				),
			],
		)
}
