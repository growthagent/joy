import pf.Console
import pf.Effect
import pf.Http
import shared.Api

## Requests to the server's JSON endpoints (see shared/Api.roc). The answer
## arrives decoded as the endpoint's answer type, or as one of the endpoint's
## errors, `Server(...)` included for whatever went wrong on the way. A page
## never reads a status or a body itself.
ApiClient := [].{
	## Send `request` to `endpoint`. A GET or a DELETE sends no body.
	send : Api.Endpoint(request, answer, [Server(Api.Failure), ..others]), request, (Try(answer, [Server(Api.Failure), ..others]) -> msg) -> Effect(msg) where [request.Json.Encodable([]), answer.Json.Parseable([InvalidJson(Str), ..errs])]
	send = |endpoint, request, done| {
		with_body = Api.has_body(endpoint)
		Http.request(
			{
				method: http_method(Api.method(endpoint)),
				uri: Api.path(endpoint),
				headers: if with_body [{ name: "Content-Type", value: "application/json" }] else [],
				body: if with_body Api.encode_request(endpoint, request).to_utf8() else [],
				timeout_ms: TimeoutMilliseconds(15_000),
			},
			|result|
				done(
					match result {
						Ok(response) => Api.decode_answer(endpoint, response.status, Str.from_utf8_lossy(response.body))
						Err(HttpErr(Timeout)) => Err(Server(Timeout))
						Err(HttpErr(NetworkError)) => Err(Server(NoAnswer)),
					},
				),
		)
	}

	## Ask an endpoint that takes no request.
	get : Api.Endpoint({}, answer, [Server(Api.Failure), ..others]), (Try(answer, [Server(Api.Failure), ..others]) -> msg) -> Effect(msg) where [answer.Json.Parseable([InvalidJson(Str), ..errs])]
	get = |endpoint, done| ApiClient.send(endpoint, {}, done)

	## Log a failed request to the browser console, with everything that is
	## known about it. The page shows the person a sentence, this is for you.
	log_problem : Str, error -> Effect(msg)
	log_problem = |what, error| Console.log("[ERROR] ${what}: ${Str.inspect(error)}")
}

http_method : Api.Method -> Http.Method
http_method = |method|
	match method {
		GET => GET
		POST => POST
		PUT => PUT
		DELETE => DELETE
	}
