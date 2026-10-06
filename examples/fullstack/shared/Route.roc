import url.Uri

## Every URL the app answers, as one type. The server parses each request
## into a route and dispatches on it (see the routing section of
## server/main.roc), and the pages build every link and every API request
## from one, so a URL is spelled in exactly one place, `to_path`. `parse` is
## its inverse, and the expects at the bottom hold the two to that.
##
## Who may use a route is not here: the server's routing table says that for
## each route, next to its handler.
Route := [].{
	Route : [
		## `/`, or `/?q=austen` with a search.
		Catalog({ query : Str }),
		## `/books/7`
		Book(I64),
		## `/books/new`
		NewBook,
		## `/loans`
		Loans,
		## `/loans.csv`, the same list as a CSV file.
		LoansCsv,
		## `/api/books/search?q=austen`
		ApiSearch({ query : Str }),
		## `/api/books`
		ApiBooks,
		## `/api/books/7/loan`
		ApiLoan(I64),
	]

	## The route a request target names. The target is the path and the
	## query as the request spelled them, still percent-encoded.
	parse : Str -> Try(Route.Route, [NotFound])
	parse = |target| {
		uri = Uri.parse(target)
		params = form_params(uri)
		match segments(Uri.path(uri)) {
			[""] => Ok(Catalog({ query: param(params, "q", "") }))
			["books", "new"] => Ok(NewBook)
			["books", id] => book_id(id).map_ok(|n| Book(n))
			["loans"] => Ok(Loans)
			["loans.csv"] => Ok(LoansCsv)
			["api", "books", "search"] => Ok(ApiSearch({ query: param(params, "q", "") }))
			["api", "books"] => Ok(ApiBooks)
			["api", "books", id, "loan"] => book_id(id).map_ok(|n| ApiLoan(n))
			_ => Err(NotFound)
		}
	}

	to_path : Route.Route -> Str
	to_path = |route|
		match route {
			Catalog({ query }) => with_param("/", "q", query, "")
			Book(id) => path(["books", id.to_str()])
			NewBook => "/books/new"
			Loans => "/loans"
			LoansCsv => "/loans.csv"
			ApiSearch({ query }) => with_param("/api/books/search", "q", query, "")
			ApiBooks => "/api/books"
			ApiLoan(id) => path(["api", "books", id.to_str(), "loan"])
		}

	## Whether the route answers JSON. A JSON route's failures are JSON
	## too, where a page route's are HTML pages.
	is_api : Route.Route -> Bool
	is_api = |route|
		match route {
			ApiSearch(_) | ApiBooks | ApiLoan(_) => Bool.True
			_ => Bool.False
		}
}

## The path's segments, each percent-decoded. A segment that is not valid
## percent-encoding is kept as it came.
segments : Str -> List(Str)
segments = |raw_path|
	raw_path.drop_prefix("/").split_on("/").map(|segment| Uri.percent_decode(segment) ?? segment)

## The query's pairs, decoded the way a browser encodes a form: `+` is a
## space and a literal plus arrives as `%2B`. The catalog's search form
## works without the client too, and that is how it sends its query.
form_params : Uri -> List((Str, Str))
form_params = |uri|
	match Uri.query(uri) {
		Query(q) => Uri.parse_query(q.replace_each("+", "%20"))
		_ => []
	}

param : List((Str, Str)), Str, Str -> Str
param = |params, key, default|
	match params.find_first(|(k, _)| k == key) {
		Ok((_, value)) => value
		Err(_) => default
	}

path : List(Str) -> Str
path = |parts| "/${Str.join_with(parts.map(Uri.percent_encode), "/")}"

## `base` with `key` set to `value`, or just `base` when the value is the
## default, so every route has one spelling.
with_param : Str, Str, Str, Str -> Str
with_param = |base, key, value, default|
	if value == default {
		base
	} else {
		Uri.parse(base).append_param(key, value).to_str()
	}

## A book id is a positive number. Anything else names no book.
book_id : Str -> Try(I64, [NotFound])
book_id = |segment|
	match I64.from_str(segment) {
		Ok(n) if n > 0 and n.to_str() == segment => Ok(n)
		_ => Err(NotFound)
	}

round_trips : Route.Route -> Bool
round_trips = |route| Route.parse(Route.to_path(route)) == Ok(route)

expect round_trips(Catalog({ query: "" }))
expect round_trips(Catalog({ query: "jane austen & co/2+2?" }))
expect round_trips(Book(7))
expect round_trips(NewBook)
expect round_trips(Loans)
expect round_trips(LoansCsv)
expect round_trips(ApiSearch({ query: "Brontë" }))
expect round_trips(ApiBooks)
expect round_trips(ApiLoan(12))

expect Route.to_path(Catalog({ query: "" })) == "/"

# A search form submits spaces as `+`.
expect Route.parse("/?q=jane+austen") == Ok(Catalog({ query: "jane austen" }))
expect Route.parse("/books/abc") == Err(NotFound)
expect Route.parse("/books/0") == Err(NotFound)
expect Route.parse("/books/-3") == Err(NotFound)
expect Route.parse("/books/007") == Err(NotFound)
expect Route.parse("/books/7/extra") == Err(NotFound)
expect Route.parse("/nowhere") == Err(NotFound)

expect Route.is_api(ApiLoan(1)) and !Route.is_api(Loans)

