import http.Response

## The plain responses the server sends: HTML documents, text and the 405.
## JSON answers go through ApiServer.roc, which builds on `json` here.
##
## Pages and API answers show the library as it is right now, so none of
## them may be cached by the browser or anything in between. The assets are
## a different matter: the platform serves those (see `init!` in main.roc).
Responses := [].{
	html : U16, Str -> Response
	html = |status, document| with_body(status, "text/html; charset=utf-8", document)

	json : U16, Str -> Response
	json = |status, body| with_body(status, "application/json; charset=utf-8", body)

	text : U16, Str -> Response
	text = |status, body| with_body(status, "text/plain; charset=utf-8", body)

	## A file for the browser to save, under `file_name`.
	download : Str, Str, Str -> Response
	download = |file_name, content_type, body|
		with_body(200, content_type, body)
			.add_header("Content-Disposition", "attachment; filename=\"${file_name}\"")

	## A 405, with the methods the route does take.
	method_not_allowed : Str -> Response
	method_not_allowed = |allowed|
		Responses.text(405, "Method not allowed")
			.add_header("Allow", allowed)
}

with_body : U16, Str, Str -> Response
with_body = |status, content_type, body|
	Response.from_status(status)
		.with_headers([
			{ name: "Content-Type", value: content_type },
			{ name: "Cache-Control", value: "no-store" },
			{ name: "X-Content-Type-Options", value: "nosniff" },
		])
		.with_body(body.to_utf8())
