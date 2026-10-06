import http.Method
import http.Response
import pf.Server
import pf.Stderr
import /ApiServer
import /Partial/Layout
import /Responses
import shared.Route

## The three ways a row of the routing table in main.roc answers its route,
## and what turns a handler's failure into a response. Nothing here knows
## about books.
##
## - `get!`: anything fetched with GET (HEAD too): a page, a redirect, a file.
## - `api!`: JSON endpoints, each with its handler (see ApiServer.roc). The
##   endpoints decide the methods.
## - `raw!`: a route that reads the request itself, like an upload. It names
##   its methods.
##
## The app has no sign-in. One that has it gives each of these an access
## level, `get!(req, ctx, AnyAdmin(|user| ...))`, so no row can leave it out.
Routing := [].{
	get! : Server.Request, (() => Try(Response, err)) => Try(Response, err)
	get! = |req, handler!|
		if req.method() == GET or req.method() == HEAD {
			handler!()
		} else {
			Ok(Responses.method_not_allowed("GET, HEAD"))
		}

	api! : Server.Request, List(ApiServer.Handler(err)) => Try(Response, err)
	api! = |req, handlers| ApiServer.serve!(req, handlers)

	raw! : Server.Request, List(Method), (() => Try(Response, err)) => Try(Response, err)
	raw! = |req, methods, handler!|
		if methods.contains(req.method()) or (req.method() == HEAD and methods.contains(GET)) {
			handler!()
		} else {
			allowed = if methods.contains(GET) methods.append(HEAD) else methods
			Ok(Responses.method_not_allowed(Str.join_with(allowed.map(Method.to_str), ", ")))
		}

	## Turn whatever a `get!` or `raw!` handler failed with, or a request
	## `api!` could not read, into a response. A JSON endpoint's own errors
	## never get here: `ApiServer.on` answers those.
	finish! : Server.Request, Route.Route, Try(Response, _) => Response
	finish! = |req, route, result|
		match result {
			Ok(response) => response
			Err(BookMissing) => if Route.is_api(route) ApiServer.request_failure(404, "There is no such book.") else Routing.not_found
			Err(NotJson) => ApiServer.request_failure(415, "Send the request as JSON, with Content-Type: application/json.")
			Err(BadRequestBody(problem)) => ApiServer.request_failure(400, "The request is not what this endpoint takes: ${problem}")
			Err(RequestBodyErr(TooLarge(_))) => ApiServer.request_failure(413, "The request is too large.")
			Err(Server(Unavailable(cause))) => {
				Stderr.line!("[WARN] ${Method.to_str(req.method())} ${Route.to_path(route)}: unavailable: ${cause}") ?? {}
				Responses.html(503, Layout.message("Back in a moment", "The server is busy for a moment. Try again shortly."))
			}

			Err(cause) => {
				Stderr.line!("[ERROR] ${Method.to_str(req.method())} ${Route.to_path(route)}: ${Str.inspect(cause)}") ?? {}
				sorry = "Something went wrong on our side. Try again in a moment."
				if Route.is_api(route) {
					ApiServer.request_failure(500, sorry)
				} else {
					Responses.html(500, Layout.message("Something went wrong", sorry))
				}
			}
		}

	## The 404 page, in the same layout as every page.
	not_found : Response
	not_found = Responses.html(404, Layout.message("Page not found", "There is no page at this address."))
}
