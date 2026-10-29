import html.Html exposing [code, div, h1, h2, h3, li, ol, p, span, strong, text]
import html.Attribute exposing [class]
import /Doc

## The topic "Server rendering and hydration".
Hydration := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Growing an app")]),
		h1([], [text("Server rendering and hydration")]),
		p(
			[class("lead")],
			[
				text("The server sends a finished page, so the visitor sees it at once. Then the client starts and takes over that same markup instead of drawing it again. Joy calls this hydration, and what makes it safe is that the model itself travels."),
			],
		),
		div(
			[class("sides")],
			[
				div(
					[class("side")],
					[
						h3([], [text("On the server")]),
						ol(
							[],
							[
								li([], [text("Read what the page needs, for example a book from the database.")]),
								li(
									[],
									[
										text("Build the page's "),
										strong([], [text("model")]),
										text(" from it: the book, and the page's starting state, an empty form and "),
										code([], [text("status: Idle")]),
										text("."),
									],
								),
								li([], [text("Render "), code([], [text("view(model)")]), text(" to HTML.")]),
								li(
									[],
									[
										text("Put that markup inside a root that names the bundle and carries the model as JSON, with "),
										code([], [text("Html.bundle")]),
										text("."),
									],
								),
							],
						),
					],
				),
				div(
					[class("side")],
					[
						h3([], [text("In the browser")]),
						ol(
							[],
							[
								li(
									[],
									[
										text("The loader, "),
										code([], [text("joy.js")]),
										text(", finds the root that names the bundle and reads the model off it."),
									],
								),
								li(
									[],
									[
										text("It calls "),
										code([], [text("mount")]),
										text(" with it and "),
										code([], [text("hydrate: true")]),
										text("."),
									],
								),
								li(
									[],
									[
										text("The bundle parses the model and hands it to the page's "),
										code([], [text("init")]),
										text(", which returns it with the effects the page starts with."),
									],
								),
								li(
									[],
									[
										text("Its first render matches the server's markup, so Joy claims the existing nodes and attaches events to them."),
									],
								),
							],
						),
					],
				),
			],
		),
		Doc.code(
			Html,
			"what the server sends, shortened",
			\\<script type="module" src="/assets/joy.js"></script>
			\\...
			\\<div data-joy-bundle="main" data-joy-flags='{"Book":{"book":{"id":7,"title":"Emma", ...},"borrower":{"email":""},"status":"Idle"}}'>
			\\  ...the book page, as the server rendered it...
			\\</div>
		),
		h2([], [text("The model is what travels")]),
		p(
			[],
			[
				text("Hydration only works when both sides draw from the same data, and the simplest way to make that certain is to send the data. The server builds the model once, because it has to render it, and the browser starts from exactly that value. So "),
				code([], [text("view")]),
				text(" lives in "),
				code([], [text("shared/")]),
				text(", the handler builds the model, and the client's "),
				code([], [text("init")]),
				text(" receives a model instead of building one:"),
			],
		),
		Doc.code(
			Roc,
			"server/Page/Books/Show.roc",
			\\page! : Ctx.Ctx, I64 => Try(Response, _)
			\\page! = |ctx, book_id| {
			\\    book = BooksSql.find!(ctx.db, book_id)?
			\\
			\\    model : App.Model
			\\    model = Book({ book, borrower: Borrower.empty, status: Idle })
			\\
			\\    Layout.document(Html.bundle({ id: Bundle.path(Main), flags: Json.to_str(model), view: App.view(model) }))
			\\}
		),
		Doc.code(
			Roc,
			"client/Page/Books/Show.roc",
			\\## Elm's init: the model is the flags. It says what the page starts with, here nothing.
			\\init : Shared.Model -> (Shared.Model, List(Effect(Shared.Msg)))
			\\init = |model| (model, [])
		),
		p(
			[],
			[
				text("Shelf keeps its pages in one bundle, so what travels is the app's union, "),
				code([], [text("Book(...)")]),
				text(" here, and the bundle's own "),
				code([], [text("init")]),
				text(" parses it and dispatches to the page. A page that is a bundle of its own sends its model bare. Either way there is no "),
				code([], [text("Flags")]),
				text(" type anywhere, and nothing builds a model but the server."),
			],
		),
		h2([], [text("Why "), code([], [text("init")]), text(" takes the model")]),
		p(
			[],
			[
				text("In a browser-only app "),
				code([], [text("init")]),
				text(" builds the model from the flags and names the effects to start with. In a full-stack app the server has already built the model, so there is nothing left to build. "),
				code([], [text("init")]),
				text(" receives it and says what the page starts with: a request, a timer, or nothing. It returns the model it was given."),
			],
		),
		p(
			[],
			[
				text("The type lets it return another, and a page may do that knowingly when the browser knows something the server could not, the current time or the window size, at the price of a first render that differs from the server's. Joy repairs the difference and warns in the console, and the browser tests treat the warning as a failure, because an unintended one means the two sides disagree. The usual way is an effect: the first render stays the server's, and what the browser knows arrives as a message a moment later."),
			],
		),
		h2([], [text("The model has to be data")]),
		p(
			[],
			[
				text("What travels is written with "),
				code([], [text("Json.to_str")]),
				text(" and read back with "),
				code([], [text("Json.parse")]),
				text(", and the compiler checks the model at those two calls. A model holding a function or a "),
				code([], [text("Box")]),
				text(" does not compile. Fractions are "),
				code([], [text("Dec")]),
				text(", because an "),
				code([], [text("F64")]),
				text(" can be NaN or infinite, which JSON cannot carry, and "),
				code([], [text("Json.to_str")]),
				text(" refuses an encoder that can fail. A type from a library is fine when the library gives it codecs, which in Roc is two lines inside the type that ask the compiler to derive them:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\Carousel(slide) :: { id : Str, items : List(slide), position : U64, ... }.{
			\\    parser_for : _
			\\    encoder_for : _
			\\}
		),
		p(
			[],
			[
				text("Elm models can hold a navigation key or a time zone. These cannot, and that is the one habit to unlearn: what only the browser knows arrives through an effect, after the first render, and is kept in the model from then on."),
			],
		),
		div(
			[class("note")],
			[
				span([class("note-label")], [text("The model is public")]),
				text(" "),
				p(
					[],
					[
						text("Everything in the model is in the page's source, whether the view shows it or not. Leave out what the visitor may not see. Shelf's "),
						code([], [text("Book.Detail")]),
						text(" has no field for who borrowed the book, so neither a book's page nor its model can carry the borrower's email."),
					],
				),
			],
		),
	]
}
