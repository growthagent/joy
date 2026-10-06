# The server: a basic-webserver app that persists todos in SQLite.
#
# It has three jobs:
#
#   1. Serve the page. `GET /` reads every todo from the database and renders
#      the whole HTML document with joy-html. The todos ride along as JSON in
#      an inert `<template>` element, which client/www/app.js reads and hands
#      to the client app as its flags, so the app boots with the stored state.
#   2. Serve the static assets under `/assets/`: all of client/www/, which
#      is the loader, the stylesheet, whatever else you drop in there, and
#      the two files build.roc puts there (the wasm module and Joy's
#      runtime). This is a native file route, declared in `init!`: the host
#      streams the files from disk without entering Roc at all.
#   3. Persist changes through a small JSON API (see the routes in
#      `respond!`), which the client calls whenever you change something in
#      the browser. Every mutation answers with the complete todo list, and
#      the client replaces its model with that answer: the database is the
#      source of truth, and the UI shows a change only once it is stored.
#
# Run it from this directory. `DB_PATH` picks the database file (default
# ./todos.db) and `PORT` the port (default 8000). The database file and
# schema are created on first start.
app [Context, program] {
	pf: platform "https://github.com/niclas-ahden/basic-webserver/releases/download/0.18.0/DuwGgLMnPKEVKXR5KuwtZRAtgap8TSp4GTnFf8ANHtXB.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
	html: "https://github.com/niclas-ahden/joy-html/releases/download/0.17.0/AcmwFzyfbsf5RALWNdX6cXw1cuuDXt96YfcysNqgFqoG.tar.zst",
	shared: "../shared/main.roc",
}

import html.Attribute exposing [attribute, content, href, id, lang, name, rel, src]
import html.Html exposing [body, div, head, html, link, meta, script, template, text, title]
import http.Response
import pf.Env
import pf.Path
import pf.Server
import pf.Sqlite
import pf.Stdout
import shared.App
import shared.Todo

# One bounded connection pool, opened in `init!` and shared by every request.
# The host checks a connection out of the pool per query, so concurrent
# `respond!` calls never contend on one connection.
#
# `test_routes` is on when the TEST_ROUTES env var is "1", which only the
# test runner sets: it enables the /reset route (see handle!) so every e2e
# test can start from an empty list. In production it is off and the route
# does not exist.
Context : { db : Sqlite.Db, test_routes : Bool }

program = { init!, respond!, shutdown! }

init! : () => Try({ config : Server.Config, context : Context }, [Exit(I64), InvalidPort(Str), CouldNotOpenDb(_), CouldNotEnsureSchema(_)])
init! = || {
	db_path =
		match Env.var!("DB_PATH") {
			Ok(path) => Path.from_os_str(path)
			Err(_) => Path.utf8("./todos.db")
		}
	port =
		match Env.var_str!("PORT") {
			Ok(raw) => U16.from_str(raw) ? |_| InvalidPort(raw)
			Err(_) => 8000
		}

	db = Sqlite.open!(Sqlite.default_config(db_path)) ? |err| CouldNotOpenDb(err)
	ensure_schema!(db) ? |err| CouldNotEnsureSchema(err)
	Stdout.line!("Using the SQLite database at ${Path.display(db_path)}") ?? {}

	test_routes = (Env.var_str!("TEST_ROUTES") ?? "") == "1"

	# All of client/www/ is mounted under /assets/, so anything dropped in
	# there (an image, a font, another stylesheet) is served by name with no
	# server change. The built app.wasm and runtime.js land there too (see
	# build.roc), so they need no routes of their own.
	www = Server.file_root({ id: "www", path: Path.utf8("client/www") })

	config =
		Server.default_config
			.with_listen({ host: "127.0.0.1", port })
			.with_file_roots([www])
			.with_native_routes({
				files: [Server.static_mount({ at: "/assets", files: www })],
				liveness: [],
				readiness: [],
			})

	Ok({ config, context: { db, test_routes } })
}

# An error a route handler lets escape is logged by the platform with request
# context and turned into a bounded 500.
respond! : Server.Request, Context => Try(Server.Outcome, [ServerErr(Str)])
respond! = |req, context|
	match handle!(req, context) {
		Ok(response) => Ok(Server.respond(response))
		Err(err) => Err(ServerErr(Str.inspect(err)))
	}

handle! : Server.Request, Context => Try(Response, _)
handle! = |req, ctx| {
	db = ctx.db

	# The API needs no query strings, so the path alone routes.
	path =
		match req.target() {
			Resource({ raw_path, .. }) => raw_path
			_ => ""
		}

	# A capture at the end of a string pattern takes everything to the end of
	# the string, so `"/todos/${raw_id}"` matches "/todos/123/foo" with
	# raw_id = "123/foo". The routes below stay honest anyway: ids that are
	# not numbers 404.
	match path {
		# The page is served on every filter path, so a refresh (or a
		# bookmark, or open-in-new-tab on a filter link) stays on that
		# filter: the path rides along in the flags and the client picks
		# its filter from it.
		"/" | "/active" | "/completed" =>
			match req.method() {
				GET => home!(db, path)
				_ => Ok(text_response(405, "Method not allowed"))
			}

		"/todos" =>
			match req.method() {
				POST => create_todo!(db, req)
				_ => Ok(text_response(405, "Method not allowed"))
			}

		"/todos/${raw_id}" =>
			match I64.from_str(raw_id) {
				Err(_) => Ok(text_response(404, "Todo ids are numbers, like /todos/1"))
				Ok(todo_id) =>
					match req.method() {
						PUT => update_todo!(db, req, todo_id)
						DELETE => delete_todo!(db, todo_id)
						_ => Ok(text_response(405, "Method not allowed"))
					}
				}

		"/toggle-all" =>
			match req.method() {
				POST => toggle_all!(db, req)
				_ => Ok(text_response(405, "Method not allowed"))
			}

		"/clear-completed" =>
			match req.method() {
				POST => clear_completed!(db)
				_ => Ok(text_response(405, "Method not allowed"))
			}

		# Only when the test runner turned it on, unknown otherwise.
		"/reset" =>
			if ctx.test_routes {
				match req.method() {
					POST => reset_todos!(db)
					_ => Ok(text_response(405, "Method not allowed"))
				}
			} else {
				Ok(text_response(404, "Not found"))
			}

		_ => Ok(text_response(404, "Not found"))
	}
}

# --- The page ---

# The page, rendered with the same view the client renders with
# (shared/App.roc), inside the #app element the client mounts into. That is
# the whole trick behind hydration: the client's first render produces this
# exact tree, so instead of building it again it claims these nodes and
# only attaches its event handlers (see client/www/app.js).
#
# The stored todos and the requested path also ride along as JSON inside a
# `<template>`: templates are inert but parsed as markup, so the entities
# the SSR text escaping produces decode back to the original JSON when
# app.js reads the element. The client boots its model from that JSON, and
# because both sides build the model with `App.page_model`, the markup and
# the model can never drift apart.
home! : Sqlite.Db, Str => Try(Response, _)
home! = |db, path| {
	todos = all_todos!(db)?

	Ok(html_response(Html.ssr_document(page(App.page_model(todos, path), Json.to_str({ todos, filter: path })))))
}

page : App.Model, Str -> Html(App.Msg)
page = |model, flags_json|
	html(
		[lang("en")],
		[
			head(
				[],
				[
					meta([attribute("charset", "utf-8")]),
					meta([name("viewport"), content("width=device-width, initial-scale=1")]),
					title([], [text("Joy TodoMVC")]),
					link([rel("stylesheet"), href("/assets/style.css")]),
					# Inline script text would be entity-escaped and inert
					# (like all SSR text), so the loader arrives as a module
					# by URL instead. It reads the template below and
					# hydrates the client app over #app.
					script([Attribute.type("module"), src("/assets/app.js")], []),
				],
			),
			body(
				[],
				[
					div([id("app")], [App.view(model)]),
					template([id("joy-model")], [text(flags_json)]),
				],
			),
		],
	)

# --- The API ---
#
# Every mutation answers with the complete stored list (see all_todos!), so
# the client never has to guess what the database now holds.

create_todo! : Sqlite.Db, Server.Request => Try(Response, _)
create_todo! = |db, req| {
	decoded : Try({ title : Str }, _)
	decoded = Json.parse(read_body!(req)?)

	match decoded {
		Err(_) => Ok(text_response(400, "Expected JSON like {\"title\": \"Buy milk\"}"))
		Ok({ title }) => {
			trimmed = title.trim()
			if trimmed.is_empty() {
				Ok(text_response(400, "The title must not be empty"))
			} else {
				Sqlite.execute!({
					db,
					query: "insert into todos (title, done) values (:title, 0)",
					params: { title: trimmed },
				}) ? |err| DbErr(err)

				todos_response!(db)
			}
		}
	}
}

update_todo! : Sqlite.Db, Server.Request, I64 => Try(Response, _)
update_todo! = |db, req, todo_id| {
	decoded : Try({ title : Str, done : Bool }, _)
	decoded = Json.parse(read_body!(req)?)

	match decoded {
		Err(_) => Ok(text_response(400, "Expected JSON like {\"title\": \"Buy milk\", \"done\": true}"))
		Ok({ title, done }) => {
			Sqlite.execute!({
				db,
				query: "update todos set title = :title, done = :done where id = :id",
				params: { title: title.trim(), done: bool_to_int(done), id: todo_id },
			}) ? |err| DbErr(err)

			todos_response!(db)
		}
	}
}

delete_todo! : Sqlite.Db, I64 => Try(Response, _)
delete_todo! = |db, todo_id| {
	Sqlite.execute!({ db, query: "delete from todos where id = :id", params: { id: todo_id } }) ? |err| DbErr(err)

	todos_response!(db)
}

toggle_all! : Sqlite.Db, Server.Request => Try(Response, _)
toggle_all! = |db, req| {
	decoded : Try({ done : Bool }, _)
	decoded = Json.parse(read_body!(req)?)

	match decoded {
		Err(_) => Ok(text_response(400, "Expected JSON like {\"done\": true}"))
		Ok({ done }) => {
			Sqlite.execute!({
				db,
				query: "update todos set done = :done",
				params: { done: bool_to_int(done) },
			}) ? |err| DbErr(err)

			todos_response!(db)
		}
	}
}

clear_completed! : Sqlite.Db => Try(Response, _)
clear_completed! = |db| {
	Sqlite.execute!({ db, query: "delete from todos where done = 1", params: {} }) ? |err| DbErr(err)

	todos_response!(db)
}

# The request body as text. The API's payloads are tiny, so the limit is
# far above anything legitimate.
read_body! : Server.Request => Try(Str, _)
read_body! = |req| {
	bytes = req.body().with_limit(16 * 1024).read_all!() ? |err| BadBody(err)
	Ok(Str.from_utf8_lossy(bytes))
}

# --- Database ---

ensure_schema! : Sqlite.Db => Try({}, _)
ensure_schema! = |db| {
	Sqlite.execute!({
		db,
		query: "create table if not exists todos (id integer primary key autoincrement, title text not null, done integer not null default 0)",
		params: {},
	})
}

# SQLite has no booleans, so `done` is stored as 0 or 1 and converted
# at the edges.
StoredTodo : { id : I64, title : Str, done : I64 }

all_todos! : Sqlite.Db => Try(List(Todo.Todo), _)
all_todos! = |db| {
	stored : List(StoredTodo)
	stored = Sqlite.query_many!({
		db,
		query: "select id, title, done from todos order by id",
		params: {},
		limits: Sqlite.default_query_limits,
	}) ? |err| DbErr(err)

	Ok(stored.map(|row| { id: row.id, title: row.title, done: row.done != 0 }))
}

bool_to_int : Bool -> I64
bool_to_int = |b| if b {
	1
} else {
	0
}

# --- Response plumbing ---

todos_response! : Sqlite.Db => Try(Response, _)
todos_response! = |db| {
	todos = all_todos!(db)?
	Ok(json_response(Json.to_str({ todos: todos })))
}

html_response : Str -> Response
html_response = |page_body|
	Response.from_status(200)
		.with_headers([
			{ name: "Content-Type", value: "text/html; charset=utf-8" },
			{ name: "Cache-Control", value: "no-store" },
		])
		.with_body(Str.to_utf8(page_body))

json_response : Str -> Response
json_response = |json_body|
	Response.from_status(200)
		.with_headers([{ name: "Content-Type", value: "application/json; charset=utf-8" }])
		.with_body(Str.to_utf8(json_body))

text_response : U16, Str -> Response
text_response = |status, text_body|
	Response.from_status(status)
		.with_headers([{ name: "Content-Type", value: "text/plain; charset=utf-8" }])
		.with_body(Str.to_utf8(text_body))

# --- Test support ---
#
# Everything below only answers when the server was started with
# TEST_ROUTES=1, which only the e2e runner sets (see e2e.roc). Reset empties
# the todo list, so each test starts from nothing even when several share a
# worker's server. Failures are not simulated here: the browser tests
# intercept the client's requests themselves (see e2e/save_failure_test.roc).

reset_todos! : Sqlite.Db => Try(Response, _)
reset_todos! = |db| {
	Sqlite.execute!({ db, query: "delete from todos", params: {} }) ? |err| DbErr(err)
	Ok(text_response(200, "OK"))
}


shutdown! : Server.ShutdownReason, Context => Try({}, [Exit(I64)])
shutdown! = |_reason, _context| Ok({})
