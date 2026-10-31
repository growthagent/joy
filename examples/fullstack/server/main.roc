# The server: a basic-webserver app over SQLite that renders every page
# for the client to hydrate and answers the client's JSON API. This file is
# the configuration and the routing table. Everything else has a module:
#
#   Page/<resource>/<action>.roc   one page's handlers, at the same path as
#                                  the page in shared/ and client/
#   Routing.roc                    the ways a row answers: get!, api!, raw!,
#                                  and finish!
#   ApiServer.roc                  answering JSON endpoints through their
#                                  handlers: on, serve!
#   Responses.roc                  HTML, text and the 405
#   Partial/Layout.roc             the document around every page
#   Sql/<entity>.roc, Db.roc       the SQL, the schema and the seed books
#   Ctx.roc                        what every handler gets
#
# How a request is answered, top to bottom:
#
#   1. `respond!` parses the request target into a `Route`
#      (shared/Route.roc), the same type the pages build their links and
#      requests from.
#   2. `route!` is the routing table: one row per route, saying who may use
#      it, with which methods, and which handler answers. The match is
#      exhaustive, so a new route does not compile until it has a row.
#   3. The row answers with `Routing.get!` (a page or a file), `Routing.api!`
#      (JSON endpoints, each with its handler, see ApiServer.roc) or
#      `Routing.raw!`. Another method gets a 405.
#   4. A JSON endpoint's errors are answered by `ApiServer.on`. Whatever
#      else fails, `Routing.finish!` turns into a response: a 4xx for the
#      client's mistakes, and for everything else a log line and a 500 that
#      says nothing about why.
#
# The assets under /assets/ and the health checks at /health/live and
# /health/ready never reach Roc: the platform answers them itself (see
# `init!`).
#
# Run it from this directory. `DB_PATH` picks the database file (default
# ./library.db), `HOST` the address to listen on (default 127.0.0.1, set
# 0.0.0.0 in a container) and `PORT` the port (default 8000). An empty
# database gets the seed books. `TEST_ROUTES=1` is for the test runner
# only.
app [Context, program] {
	pf: platform "https://github.com/niclas-ahden/basic-webserver/releases/download/0.20.0/8gawVMwxgrwBefBfG9kAMVeJQ68b8kd1tTAAsX1xUtTe.tar.zst",
	# The same URL basic-webserver names for this package. Another URL for
	# the same package makes `roc test` plan the package twice and crash.
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
	shared: "../shared/main.roc",
}

import http.Response
import pf.Env
import pf.OsStr
import pf.Path
import pf.Server
import pf.Sqlite
import pf.Stderr
import pf.Stdout
import /ApiServer
import /Ctx
import /Db
import /Page/Books/Index as ServerBooksIndex
import /Page/Books/New as ServerBooksNew
import /Page/Books/Show as ServerBooksShow
import /Page/Loans/Index as ServerLoansIndex
import /Responses
import /Routing
import shared.PageBooksIndex
import shared.PageBooksNew
import shared.PageBooksShow
import shared.Route

Context : Ctx.Ctx

program = { init!, respond!, shutdown! }

init! : () => Try({ config : Server.Config, context : Context }, _)
init! = || {
	db_path =
		match Env.var!("DB_PATH") {
			Ok(path) => Path.from_os_str(path)
			Err(_) => Path.utf8("./library.db")
		}
	host = Env.var_str!("HOST") ?? "127.0.0.1"
	port =
		match Env.var_str!("PORT") {
			Ok(raw) => U16.from_str(raw) ? |_| InvalidPort(raw)
			Err(_) => 8000
		}

	db = Sqlite.open!(Sqlite.default_config(db_path)) ? |err| CouldNotOpenDb(err)
	Db.ensure_schema!(db) ? |err| CouldNotCreateSchema(err)
	Db.seed_books!(db) ? |err| CouldNotSeedBooks(err)

	# All of client/www/ is served under /assets/ by the platform itself:
	# the loader, the stylesheet, and the wasm and runtime build.roc puts
	# there. Drop a file in and it is served, with no route to write.
	www = Server.file_root({ id: "www", path: Path.utf8("client/www") })

	# Health checks for a container runtime or a load balancer, answered by
	# the platform even while every Roc handler is busy. /health/live
	# answers 200 while the server runs. /health/ready answers 200 too,
	# until a graceful stop begins and turns it to 503, so traffic moves
	# elsewhere before the server goes away. Both are ready from the start:
	# everything `init!` needs is done before the platform starts listening.
	readiness = Server.Readiness.create!(Ready) ? |err| CouldNotCreateReadiness(err)

	listening = Server.with_listen(Server.default_config, { host, port })
	serving = Server.with_file_roots(listening, [www])
	config = Server.with_native_routes(serving, {
		files: [Server.static_mount({ at: "/assets", files: www })],
		liveness: [Server.liveness_route("/health/live")],
		readiness: [Server.readiness_route({ at: "/health/ready", readiness })],
	})

	Stdout.line!("Listening on http://${host}:${port.to_str()} with the database at ${Path.display(db_path)}") ?? {}

	Ok({
		config,
		context: {
			db,
			test_routes: flag!("TEST_ROUTES", Bool.False),
			readiness,
		},
	})
}

## An on/off setting: "1" is on, "0" is off, anything else is `default`.
flag! : Str, Bool => Bool
flag! = |var_name, default|
	match Env.var_str!(OsStr.utf8(var_name)) {
		Ok("1") => Bool.True
		Ok("0") => Bool.False
		_ => default
	}

respond! : Server.Request, Context => Try(Server.Outcome, [ServerErr(Str)])
respond! = |req, ctx| {
	response =
		match req.target() {
			Resource({ raw_path, raw_query }) => {
				target =
					match raw_query {
						Present(query) => "${raw_path}?${query}"
						Absent => raw_path
					}
				match Route.parse(target) {
					Ok(route) => Routing.finish!(req, route, route!(req, ctx, route))
					Err(NotFound) =>
						if ctx.test_routes and raw_path == "/test/reset" {
							test_reset!(req, ctx)
						} else if raw_path.starts_with("/api/") {
							ApiServer.request_failure(404, "There is no such endpoint.")
						} else {
							Routing.not_found
						}
				}
			}

			# `CONNECT host:port` and `OPTIONS *` name nothing here.
			_ => Responses.text(400, "Bad request")
		}
	Ok(Server.respond(response))
}

shutdown! : Server.ShutdownReason, Context => Try({}, [Exit(I64)])
shutdown! = |_reason, _context| Ok({})

## The routing table. Each row says who may use the route, with which
## methods, and which handler answers it.
route! : Server.Request, Context, Route.Route => Try(Response, _)
route! = |req, ctx, route|
	match route {
		Catalog({ query }) => Routing.get!(req, || ServerBooksIndex.page!(ctx, query))
		Book(book_id) => Routing.get!(req, || ServerBooksShow.page!(ctx, book_id))
		NewBook => Routing.get!(req, || ServerBooksNew.page!())
		Loans => Routing.get!(req, || ServerLoansIndex.page!(ctx))
		LoansCsv => Routing.get!(req, || ServerLoansIndex.csv!(ctx))
		ApiSearch({ query }) =>
			Routing.api!(req, [ApiServer.on(PageBooksIndex.search_books(query), |{}| ServerBooksIndex.search!(ctx, query))])

		ApiBooks =>
			Routing.api!(req, [ApiServer.on(PageBooksNew.add_book, |book| ServerBooksNew.add!(ctx, book))])

		ApiLoan(book_id) =>
			Routing.api!(
				req,
				[
					ApiServer.on(PageBooksShow.borrow(book_id), |borrower| ServerBooksShow.borrow!(ctx, book_id, borrower)),
					ApiServer.on(PageBooksShow.give_back(book_id), |{}| ServerBooksShow.give_back!(ctx, book_id)),
				],
			)
	}

# ---- Test support ----
#
# Only when TEST_ROUTES=1, which only the test runner sets: puts the seed
# books back, with nothing on loan, so every test starts from the same
# library.

test_reset! : Server.Request, Context => Response
test_reset! = |req, ctx|
	if req.method() != POST {
		Responses.method_not_allowed("POST")
	} else {
		match Db.reset_books!(ctx.db) {
			Ok({}) => Responses.text(200, "OK")
			Err(cause) => {
				Stderr.line!("[ERROR] POST /test/reset: ${Str.inspect(cause)}") ?? {}
				Responses.text(500, "Reset failed")
			}
		}
	}
