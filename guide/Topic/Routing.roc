import html.Html exposing [code, div, h1, h2, li, p, span, text, ul]
import html.Attribute exposing [class]
import /Doc

## The topic "The routing table".
Routing := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Growing an app")]),
		h1([], [text("The routing table")]),
		p(
			[class("lead")],
			[
				text("On the server, one "),
				code([], [text("match")]),
				text(" on the route decides how every request is answered. It is exhaustive, so a new route does not compile until it has a row."),
			],
		),
		Doc.code(
			Roc,
			"server/main.roc, from Shelf",
			\\route! : Server.Request, Context, Route.Route => Try(Response, _)
			\\route! = |req, ctx, route|
			\\    match route {
			\\        Catalog({ query }) => Routing.get!(req, || ServerBooksIndex.page!(ctx, query))
			\\        Book(book_id) => Routing.get!(req, || ServerBooksShow.page!(ctx, book_id))
			\\        NewBook => Routing.get!(req, || ServerBooksNew.page!())
			\\
			\\        ApiLoan(book_id) =>
			\\            Routing.api!(req, [
			\\                ApiServer.on(PageBooksShow.borrow(book_id), |borrower| ServerBooksShow.borrow!(ctx, book_id, borrower)),
			\\                ApiServer.on(PageBooksShow.give_back(book_id), |{}| ServerBooksShow.give_back!(ctx, book_id)),
			\\            ])
			\\    }
		),
		p([], [text("Each row answers in one of three ways:")]),
		ul(
			[],
			[
				li(
					[],
					[
						code([], [text("get!")]),
						text(" for anything fetched with GET: a page, a redirect, a file. HEAD is answered like GET."),
					],
				),
				li(
					[],
					[
						code([], [text("api!")]),
						text(" for a route's JSON endpoints, each with its handler. The endpoints decide which methods the route takes."),
					],
				),
				li(
					[],
					[
						code([], [text("raw!")]),
						text(" for a route that reads the request itself, like a file upload."),
					],
				),
			],
		),
		p(
			[],
			[
				text("Any other method gets a 405. The rest of "),
				code([], [text("main.roc")]),
				text(" is configuration."),
			],
		),
		h2([], [text("Who may use a route")]),
		p([], [text("In an app with sign-in, give each row an access level as a tag around its handler:")]),
		Doc.code(
			Roc,
			"",
			\\Loans => get!(req, ctx, AnyAdmin(|user| ServerLoansIndex.page!(ctx, user)))
			\\Catalog({ query }) => get!(req, ctx, Public(|| ServerBooksIndex.page!(ctx, query)))
		),
		p(
			[],
			[
				text("No row can leave the level out, and a handler gets the signed-in user exactly when the level means there is one."),
			],
		),
		div(
			[class("note")],
			[
				span([class("note-label")], [text("Where these come from")]),
				text(" "),
				p(
					[],
					[
						code([], [text("Route")]),
						text(", "),
						code([], [text("Routing")]),
						text(", "),
						code([], [text("Api")]),
						text(", "),
						code([], [text("ApiServer")]),
						text(" and "),
						code([], [text("ApiClient")]),
						text(" are modules of the Shelf example, not part of Joy itself. They are small. Copy them into your app and change them to fit."),
					],
				),
			],
		),
	]
}
