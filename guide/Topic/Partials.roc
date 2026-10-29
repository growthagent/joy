import html.Html exposing [code, h1, h2, p, text]
import html.Attribute exposing [class]
import /Doc

## The topic "Partials".
Partials := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Structuring for scale")]),
		h1([], [text("Partials")]),
		p(
			[class("lead")],
			[
				text("A partial is a piece of view that several pages show: a header, a footer, a list of results. It has no state and no update of its own. It is a function, on the first three steps of the ladder."),
			],
		),
		Doc.code(
			Roc,
			"shared/Partial/Menu.roc, from Shelf",
			\\Menu := [].{
			\\    ## Which entry is the current one.
			\\    Section : [Catalog, Loans, NewBook, Nowhere]
			\\
			\\    view : Section -> Html(msg)
			\\    view = |current|
			\\        header([class("top")], [
			\\            nav([class("links")], [
			\\                entry("Catalog", Catalog({ query: "" }), current == Catalog),
			\\                entry("On loan", Loans, current == Loans),
			\\                entry("Add a book", NewBook, current == NewBook),
			\\            ]),
			\\        ])
			\\}
		),
		p(
			[],
			[
				text("The menu is built only from what it is given, and its type, "),
				code([], [text("Html(msg)")]),
				text(", says it sends nothing. The app's pages show it, and so do the server's 404 and 500 pages, so the whole site has one header."),
			],
		),
		h2([], [text("Let the caller name the messages")]),
		p(
			[],
			[
				text("When a partial has buttons, let the caller pass the messages in. Do not write the page's message tags inside the partial."),
			],
		),
		Doc.code(
			Roc,
			"",
			\\# Ties the partial to one page: it only works where Msg has Booking(Opened(_)).
			\\showings : List(Showing) -> Html(_)
			\\showings = |list| ul([], list.map(|s| li([], [button([on_click(Booking(Opened(s.id)))], [text(s.time)])])))
			\\
			\\# Works for any page, and the type shows what it can send.
			\\showings : List(Showing), (I64 -> msg) -> Html(msg)
			\\showings = |list, book| ul([], list.map(|s| li([], [button([on_click(book(s.id))], [text(s.time)])])))
		),
		p(
			[],
			[
				text("The second version is the same idea as "),
				code([], [text("on_click")]),
				text(" itself: the element does not know your messages, you tell it which one to send. A partial that names a page's tags looks reusable but only works on that one page."),
			],
		),
	]
}
