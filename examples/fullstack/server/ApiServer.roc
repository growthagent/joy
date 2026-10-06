import http.Header
import http.Method
import http.Response
import pf.Server
import pf.Stderr
import /Responses
import shared.Api

## The server's end of the JSON endpoints (see shared/Api.roc), the mirror of
## client/ApiClient.roc. A route's row in the routing table hands each of its
## endpoints a handler:
##
## ```roc
## ApiLoan(book_id) =>
##     Routing.api!(req, [
##         ApiServer.on(PageBooksShow.borrow(book_id), |borrower| ServerBooksShow.borrow!(ctx, book_id, borrower)),
##         ApiServer.on(PageBooksShow.give_back(book_id), |{}| ServerBooksShow.give_back!(ctx, book_id)),
##     ])
## ```
##
## A handler takes the endpoint's request and returns its answer or one of
## its errors, and nothing else: it reads no body, sets no status and builds
## no JSON. `on` does that, and the endpoint's types make sure the handler
## can only answer with what the page decodes.
ApiServer := [].{
	## One endpoint and what answers it, with the endpoint's types gone, so
	## the endpoints of one route fit in one list.
	Handler(err) : { method : Method, run! : Server.Request => Try(Response, err) }

	## Answer `endpoint` with `handler!`. The request body is read as the
	## endpoint's request type (only JSON is taken: a form on another site can
	## post form data or plain text here without asking, but a JSON body makes
	## the browser ask this server first, and it never says yes). The answer
	## goes out with the endpoint's success status, an error with the status
	## the endpoint gives it. A `Server` failure is logged here, with the
	## request it came from, and loses its details on the way out.
	on : Api.Endpoint(request, answer, [Server(Api.Failure), ..others]), (request => Try(answer, [Server(Api.Failure), ..others])) -> ApiServer.Handler(_) where [request.Json.Parseable([InvalidJson(Str), ..errs]), answer.Json.Encodable([])]
	on = |endpoint, handler!| {
		method: http_method(Api.method(endpoint)),
		run!: |req| {
			request = read_request!(req, endpoint)?
			match handler!(request) {
				Ok(answer) => {
					(status, body) = Api.encode_answer(endpoint, answer)
					Ok(Responses.json(status, body))
				}

				Err(error) => {
					server_side = from_server(error)
					log!(req, server_side)
					(status, body) = Api.encode_error(endpoint, server_side)
					Ok(Responses.json(status, body))
				}
			}
		},
	}

	## Run the handler whose endpoint takes the request's method (HEAD counts
	## as GET). Any other method gets a 405 that names the ones there are.
	serve! : Server.Request, List(ApiServer.Handler(err)) => Try(Response, err)
	serve! = |req, handlers| {
		method = if req.method() == HEAD GET else req.method()
		match handlers.find_first(|handler| handler.method == method) {
			Ok(handler) => (handler.run!)(req)
			Err(_) => Ok(Responses.method_not_allowed(allow_header(handlers.map(|handler| handler.method))))
		}
	}

	## A failure of the request itself, before any endpoint's handler ran: not
	## JSON, the wrong shape, too large, an endpoint that does not exist. These
	## are bugs in a client, so the body is plain words for whoever debugs it,
	## and a page sees them as `Server(Unexpected(status, body))`.
	request_failure : U16, Str -> Response
	request_failure = |status, problem| Responses.json(status, Json.to_str({ error: problem }))
}

## The request as the endpoint's request type. An endpoint that sends no
## body (GET, DELETE) takes `{}`.
read_request! : Server.Request, Api.Endpoint(request, answer, error) => Try(request, _) where [request.Json.Parseable([InvalidJson(Str), ..errs])]
read_request! = |req, endpoint|
	if !Api.has_body(endpoint) {
		Api.decode_request(endpoint, "{}".to_utf8())
	} else if is_json(req.headers()) {
		body = req.body().with_limit(64 * 1024).read_all!()?
		Api.decode_request(endpoint, body)
	} else {
		Err(NotJson)
	}

## The failures only a client can see (no answer, a timeout, an unexpected
## or unreadable answer) make no sense from a handler. One that returns them
## anyway has a bug.
from_server : [Server(Api.Failure), ..others] -> [Server(Api.Failure), ..others]
from_server = |error|
	match error {
		Server(NoAnswer) | Server(Timeout) | Server(Unexpected(_, _)) | Server(Incompatible(_)) =>
			Server(Bug("a handler returned ${Str.inspect(error)}, which only a client can see"))

		other => other
	}

## Every `Server` failure is logged with the request it came from. The
## endpoint's own errors are answers, not failures, so they are not. An error
## tracker (Sentry, say) plugs in here.
log! : Server.Request, [Server(Api.Failure), ..others] => {}
log! = |req, error| {
	at = "${Method.to_str(req.method())} ${request_path(req)}"
	line =
		match error {
			Server(Unavailable(cause)) => Ok("[WARN] ${at}: unavailable: ${cause}")
			Server(Upstream(service, cause)) => Ok("[ERROR] ${at}: ${service} failed: ${cause}")
			Server(failure) => Ok("[ERROR] ${at}: ${Str.inspect(failure)}")
			_ => Err(NotLogged)
		}
	match line {
		Ok(text) => Stderr.line!(text) ?? {}
		Err(NotLogged) => {}
	}
}

request_path : Server.Request -> Str
request_path = |req|
	match req.target() {
		Resource({ raw_path, .. }) => raw_path
		_ => "?"
	}

is_json : List(Header) -> Bool
is_json = |headers|
	headers.any(|header| header.name.with_ascii_lowercased() == "content-type" and header.value.with_ascii_lowercased().starts_with("application/json"))

http_method : Api.Method -> Method
http_method = |method|
	match method {
		GET => GET
		POST => POST
		PUT => PUT
		DELETE => DELETE
	}

## The `Allow` header of a 405: the methods there are, and HEAD with GET.
allow_header : List(Method) -> Str
allow_header = |methods| {
	allowed = if methods.contains(GET) methods.append(HEAD) else methods
	Str.join_with(allowed.map(Method.to_str), ", ")
}

expect allow_header([GET]) == "GET, HEAD" and allow_header([POST, DELETE]) == "POST, DELETE"
