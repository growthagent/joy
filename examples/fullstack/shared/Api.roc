## The JSON endpoints between the client and its own server, typed on both
## ends. An endpoint is a method and a path and, as types, the request it
## takes, the answer it gives and the errors it can fail with. The pages
## define each endpoint once, the client sends with it (client/ApiClient.roc)
## and the server answers through it (server/ApiServer.roc), so a field
## renamed on one side, or an error one side does not know, is a compile
## error on the other instead of a surprise in production.
##
## ```roc
## # shared: the endpoint, its errors and their statuses
## BorrowError : [BookMissing, AlreadyOnLoan, BadEmail(Str), Server(Api.Failure)]
##
## borrow : I64 -> Api.Endpoint(Book.Borrower, Book.Detail, BorrowError)
## borrow = |book_id|
##     Api.post(
##         Route.to_path(ApiLoan(book_id)),
##         |error|
##             match error {
##                 BookMissing => 404
##                 AlreadyOnLoan => 409
##                 BadEmail(_) => 422
##                 Server(failure) => Api.failure_status(failure)
##             },
##     )
##
## # server: the handler returns the answer or one of those errors
## ApiServer.on(PageBooksShow.borrow(book_id), |borrower| ServerBooksShow.borrow!(ctx, book_id, borrower))
##
## # client: the page gets Try(Book.Detail, BorrowError)
## ApiClient.send(PageBooksShow.borrow(book_id), borrower, |answer| ServerAnsweredBorrow(answer))
## ```
##
## Every endpoint's errors include `Server(Api.Failure)`: whatever went wrong
## that is not one of the endpoint's own errors, on the server or between it
## and the page.
Api := [].{
	Endpoint(request, answer, error) :: {
		method : Method,
		path : Str,
		## The status of a successful answer: 200, or 201 for `created`.
		success : U16,
		## The status each error goes out with.
		status : error -> U16,
		parse_error : Str -> Try(error, [NotAnError]),
		encode_error : error -> Str,
	}

	Method : [GET, POST, PUT, DELETE]

	## Everything that can go wrong that is not one of an endpoint's own
	## errors. The first four come from the client, the rest from the server.
	Failure : [
		## No answer at all: offline, DNS, a refused or dropped connection.
		## The browser cannot tell these apart.
		NoAnswer,
		## No answer within the request's time limit.
		Timeout,
		## A status this endpoint never answers with, and the body: a proxy's
		## error page, a route that no longer exists.
		Unexpected(U16, Str),
		## An answer this page cannot read, and why. Usually the page and the
		## server are different versions: a reload fixes it.
		Incompatible(Str),
		## Something the server needs is briefly out. 503.
		Unavailable(Str),
		## A service the server depends on failed: its name and the cause. 502.
		Upstream(Str, Str),
		## Anything the server did not plan for. 500.
		Bug(Str),
	]

	## An endpoint that only reads, and so sends no body.
	get : Str, (error -> U16) -> Api.Endpoint({}, answer, error) where [error.Json.Parseable([InvalidJson(Str), ..errs]), error.Json.Encodable([])]
	get = |path, status| endpoint(GET, path, 200, status)

	post : Str, (error -> U16) -> Api.Endpoint(request, answer, error) where [error.Json.Parseable([InvalidJson(Str), ..errs]), error.Json.Encodable([])]
	post = |path, status| endpoint(POST, path, 200, status)

	## A POST that answers 201: it stored something new.
	created : Str, (error -> U16) -> Api.Endpoint(request, answer, error) where [error.Json.Parseable([InvalidJson(Str), ..errs]), error.Json.Encodable([])]
	created = |path, status| endpoint(POST, path, 201, status)

	put : Str, (error -> U16) -> Api.Endpoint(request, answer, error) where [error.Json.Parseable([InvalidJson(Str), ..errs]), error.Json.Encodable([])]
	put = |path, status| endpoint(PUT, path, 200, status)

	## An endpoint that deletes, and sends no body.
	delete : Str, (error -> U16) -> Api.Endpoint({}, answer, error) where [error.Json.Parseable([InvalidJson(Str), ..errs]), error.Json.Encodable([])]
	delete = |path, status| endpoint(DELETE, path, 200, status)

	method : Api.Endpoint(request, answer, error) -> Api.Method
	method = |e| e.method

	path : Api.Endpoint(request, answer, error) -> Str
	path = |e| e.path

	## Whether the endpoint's request travels as a body.
	has_body : Api.Endpoint(request, answer, error) -> Bool
	has_body = |e| e.method == POST or e.method == PUT

	## The status a `Failure` goes out with. An endpoint's status function
	## hands its `Server(failure)` errors to this.
	failure_status : Api.Failure -> U16
	failure_status = |failure|
		match failure {
			Unavailable(_) => 503
			Upstream(_, _) => 502
			_ => 500
		}

	## Words for a `Failure`, for a page that has nothing more specific to
	## say about it.
	failure_text : Api.Failure -> Str
	failure_text = |failure|
		match failure {
			NoAnswer | Timeout => "Could not reach the server. Check your connection and try again."
			Unexpected(404, _) | Unexpected(405, _) | Incompatible(_) => "This page is out of date. Reload to continue."
			Unexpected(_, _) => "Something went wrong talking to the server. Try again."
			Unavailable(_) => "The server is busy for a moment. Try again shortly."
			Upstream(_, _) => "A service we depend on is not answering. Try again later."
			Bug(_) => "Something went wrong on our side. Try again in a moment."
		}

	## The body a client sends.
	encode_request : Api.Endpoint(request, answer, error), request -> Str where [request.Json.Encodable([])]
	encode_request = |_endpoint, request| Json.to_str(request)

	## The request a server got, or why its body is not one.
	decode_request : Api.Endpoint(request, answer, error), List(U8) -> Try(request, [BadRequestBody(Str)]) where [request.Json.Parseable([InvalidJson(Str), ..errs])]
	decode_request = |_endpoint, body|
		match Json.parse(Str.from_utf8_lossy(body)) {
			Ok(request) => Ok(request)
			Err(problem) => Err(BadRequestBody(Str.inspect(problem)))
		}

	## The status and body a server answers with.
	encode_answer : Api.Endpoint(request, answer, error), answer -> (U16, Str) where [answer.Json.Encodable([])]
	encode_answer = |e, answer| (e.success, Json.to_str(answer))

	## The status and body a server fails with. A `Server` failure loses its
	## details on the way out: they are for the server's own logs, never for
	## the browser.
	encode_error : Api.Endpoint(request, answer, [Server(Api.Failure), ..others]), [Server(Api.Failure), ..others] -> (U16, Str)
	encode_error = |e, error| {
		public =
			match error {
				Server(Bug(_)) => Server(Bug(""))
				Server(Unavailable(_)) => Server(Unavailable(""))
				Server(Upstream(service, _)) => Server(Upstream(service, ""))
				other => other
			}
		((e.status)(error), (e.encode_error)(public))
	}

	## What a client makes of a status and a body: the endpoint's answer, one
	## of its errors, or the `Server` failure that says why neither came.
	decode_answer : Api.Endpoint(request, answer, [Server(Api.Failure), ..others]), U16, Str -> Try(answer, [Server(Api.Failure), ..others]) where [answer.Json.Parseable([InvalidJson(Str), ..errs])]
	decode_answer = |e, status, body|
		if status == e.success {
			match Json.parse(body) {
				Ok(answer) => Ok(answer)
				Err(problem) => Err(Server(Incompatible(Str.inspect(problem))))
			}
		} else {
			match (e.parse_error)(body) {
				Ok(error) => Err(error)
				# A busy server's own 503 (a full queue, a graceful stop)
				# carries no error of ours, and means the same thing.
				Err(NotAnError) if status == 503 => Err(Server(Unavailable("")))
				Err(NotAnError) => Err(Server(Unexpected(status, body)))
			}
		}
}

endpoint : Api.Method, Str, U16, (error -> U16) -> Api.Endpoint(request, answer, error) where [error.Json.Parseable([InvalidJson(Str), ..errs]), error.Json.Encodable([])]
endpoint = |method, path, success, status| {
	method,
	path,
	success,
	status,
	parse_error: |text| Json.parse(text).map_err(|_| NotAnError),
	encode_error: |error| Json.to_str(error),
}

Saved : { id : I64, name : Str }

SaveError : [Taken, Server(Api.Failure)]

save : Api.Endpoint({ name : Str }, Saved, SaveError)
save = Api.post(
	"/things",
	|error|
		match error {
			Taken => 409
			Server(failure) => Api.failure_status(failure)
		},
)

expect Api.encode_request(save, { name: "x\"y" }) == "{\"name\":\"x\\\"y\"}"
expect Api.decode_request(save, "{\"name\":\"x\"}".to_utf8()) == Ok({ name: "x" })
expect Api.decode_request(save, "{\"nom\":\"x\"}".to_utf8()).is_err()
expect Api.path(save) == "/things" and Api.method(save) == POST and Api.has_body(save)

# An answer and an error survive the trip, with their statuses.
expect {
	(status, body) = Api.encode_answer(save, { id: 1, name: "x" })
	Api.decode_answer(save, status, body) == Ok({ id: 1, name: "x" })
}
expect {
	(status, body) = Api.encode_error(save, Taken)
	status == 409 and Api.decode_answer(save, status, body) == Err(Taken)
}

# A server failure keeps its status but loses its details on the way out.
expect {
	(status, body) = Api.encode_error(save, Server(Bug("the database password is hunter2")))
	status == 500 and !body.contains("hunter2") and Api.decode_answer(save, status, body) == Err(Server(Bug("")))
}
expect {
	(status, _) = Api.encode_error(save, Server(Upstream("Mail", "timeout")))
	status == 502
}

# Anything else that comes back says what it was.
expect Api.decode_answer(save, 200, "{\"id\":\"1\"}").is_err()
expect
	match Api.decode_answer(save, 200, "{\"id\":\"1\"}") {
		Err(Server(Incompatible(_))) => Bool.True
		_ => Bool.False
	}
expect Api.decode_answer(save, 502, "<h1>Bad gateway</h1>") == Err(Server(Unexpected(502, "<h1>Bad gateway</h1>")))
expect Api.decode_answer(save, 503, "busy") == Err(Server(Unavailable("")))

expect {
	remove : Api.Endpoint({}, {}, [Server(Api.Failure)])
	remove = Api.delete("/things/1", |_| 500)
	!Api.has_body(remove)
}
expect Api.failure_text(Timeout) == Api.failure_text(NoAnswer)
expect Api.failure_text(Unexpected(404, "")).contains("Reload")
