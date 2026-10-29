import html.Html exposing [code, div, h1, h2, h3, li, p, text, ul]
import html.Attribute exposing [class]
import /Doc

## The topic "Three folders: shared, client, server".
Fullstack := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Growing an app")]),
		h1([], [text("Three folders: shared, client, server")]),
		p(
			[class("lead")],
			[
				text("A full-stack Joy app keeps its code in three folders, one for each place it runs. A page that runs in the browser lives at the same path in all three."),
			],
		),
		p(
			[],
			[
				text("The Joy repository's "),
				code([], [text("examples/fullstack")]),
				text(" is a small lending library called Shelf, and the rest of this part follows it."),
			],
		),
		div(
			[class("folders")],
			[
				div(
					[class("folder")],
					[
						h3([], [text("shared/")]),
						p([], [text("Compiled into both the browser and the server.")]),
						ul(
							[],
							[
								li([], [text("Each page's model, messages, view and endpoints")]),
								li(
									[],
									[
										text("Routes, partials, and the models and views of other pieces with their own state"),
									],
								),
								li([], [text("Types and rules both sides use")]),
							],
						),
					],
				),
				div(
					[class("folder")],
					[
						h3([], [text("client/")]),
						p([], [text("Compiled to WebAssembly. Only runs in the browser.")]),
						ul(
							[],
							[
								li(
									[],
									[
										text("Every "),
										code([], [text("init")]),
										text(", "),
										code([], [text("update")]),
										text(" and "),
										code([], [text("subscriptions")]),
									],
								),
								li([], [text("The bundles, the Joy apps that run them")]),
								li([], [text("Sending requests to the server")]),
							],
						),
					],
				),
				div(
					[class("folder")],
					[
						h3([], [text("server/")]),
						p([], [text("Compiled for the server. Only runs there.")]),
						ul(
							[],
							[
								li([], [text("Each page's handlers")]),
								li([], [text("The routing table")]),
								li(
									[],
									[
										text("SQL, the HTML document around pages, and the views of pages the server alone renders"),
									],
								),
							],
						),
					],
				),
			],
		),
		Doc.code(
			Text,
			"",
			\\shared/Page/Books/Show.roc    Model, Msg, view, the endpoints
			\\client/Page/Books/Show.roc    init, update, subscriptions
			\\server/Page/Books/Show.roc    page!, borrow!, give_back!
			\\client/main.roc               the bundle: Shelf's one Joy app, with every page in it
		),
		p(
			[],
			[
				text("Pages are named by resource and action, like "),
				code([], [text("Page/Books/Index.roc")]),
				text(" for the catalog and "),
				code([], [text("Page/Books/New.roc")]),
				text(" for the form that adds a book. Knowing one half tells you where the other two are."),
			],
		),
		h2([], [text("Which folder a function goes in")]),
		p(
			[],
			[
				text("One rule decides it. If a function's type mentions "),
				code([], [text("Effect")]),
				text(" or "),
				code([], [text("Sub")]),
				text(", it goes in "),
				code([], [text("client/")]),
				text(", because those are types of Joy's platform and only a Joy app can import them. Everything else a page needs, its model, its messages, its view and its endpoints, goes in "),
				code([], [text("shared/")]),
				text(", so the server can render the page from the same code the browser runs. Handlers and SQL go in "),
				code([], [text("server/")]),
				text(". A page the server alone renders, with no state of its own in the browser, has no client half at all, and its view sits next to its handler in "),
				code([], [text("server/")]),
				text(". Bundles says which pages those are."),
			],
		),
		h2([], [text("The folders keep the sides apart")]),
		ul(
			[],
			[
				li(
					[],
					[
						code([], [text("shared/")]),
						text(" cannot import Joy's platform or the server's. A view in shared cannot do I/O, so both sides can render it."),
					],
				),
				li([], [code([], [text("client/")]), text(" cannot reach the database.")]),
				li([], [code([], [text("server/")]), text(" cannot use browser effects.")]),
			],
		),
		p([], [text("A wrong import does not compile, so the line between the sides is checked for you.")]),
		h2([], [text("Importing by path")]),
		p([], [text("A module in a folder is imported by its path from the package root:")]),
		Doc.code(
			Roc,
			"",
			\\import /Page/Books/Show as PageBooksShow
			\\import /Book
		),
		p(
			[],
			[
				text("A bare "),
				code([], [text("import Book")]),
				text(" inside "),
				code([], [text("Page/Books/")]),
				text(" would look for "),
				code([], [text("Page/Books/Book.roc")]),
				text(", next to the importing file, which is why nested modules write "),
				code([], [text("import /Book")]),
				text(". The shared package's "),
				code([], [text("main.roc")]),
				text(" gives each nested module a flat name, like "),
				code([], [text("shared.PageBooksShow")]),
				text(", for the client and server to use."),
			],
		),
	]
}
