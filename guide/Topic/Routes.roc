import html.Html exposing [code, h1, p, text]
import html.Attribute exposing [class]
import /Doc

## The topic "One type for every URL".
Routes := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Growing an app")]),
		h1([], [text("One type for every URL")]),
		p(
			[class("lead")],
			[
				text("Every URL the app answers is a tag of one type. The server turns a request into a route with "),
				code([], [text("parse")]),
				text(", and every link and request is built from a route with "),
				code([], [text("to_path")]),
				text("."),
			],
		),
		Doc.code(
			Roc,
			"shared/Route.roc, shortened",
			\\Route := [].{
			\\   Route : [
			\\       ## `/`, or `/?q=austen` with a search.
			\\       Catalog({ query : Str }),
			\\       ## `/books/7`
			\\       Book(I64),
			\\       ## `/books/new`
			\\       NewBook,
			\\       ## `/api/books/7/loan`
			\\       ApiLoan(I64),
			\\   ]
			\\
			\\   parse : Str -> Try(Route.Route, [NotFound])
			\\
			\\   to_path : Route.Route -> Str
			\\   to_path = |route|
			\\       match route {
			\\           Catalog({ query }) => with_param("/", "q", query, "")
			\\           Book(id) => path(["books", id.to_str()])
			\\           NewBook => "/books/new"
			\\           ApiLoan(id) => path(["api", "books", id.to_str(), "loan"])
			\\       }
			\\}
			\\
			\\round_trips : Route.Route -> Bool
			\\round_trips = |route| Route.parse(Route.to_path(route)) == Ok(route)
			\\
			\\expect round_trips(Book(7))
		),
		p(
			[],
			[
				text("A link is then "),
				code([], [text("a([href(Route.to_path(Book(book.id)))], [text(book.title)])")]),
				text(", never a string you type by hand. Each URL is spelled in exactly one place, and the "),
				code([], [text("expect")]),
				text(" lines hold "),
				code([], [text("parse")]),
				text(" to be the inverse of "),
				code([], [text("to_path")]),
				text("."),
			],
		),
		p(
			[],
			[
				text("Rename a URL and every link follows. Remove a route and every link to it stops compiling."),
			],
		),
	]
}
