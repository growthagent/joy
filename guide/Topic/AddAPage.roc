import html.Html exposing [code, div, h1, h2, li, ol, p, table, tbody, td, text, th, thead, tr]
import html.Attribute exposing [class]
import /Doc

## The topic "Adding a page".
AddAPage := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Reference")]),
		h1([], [text("Adding a page")]),
		p(
			[class("lead")],
			[
				text("In a full-stack app, adding a page is a fixed list. The compiler checks each step and points you to the next one."),
			],
		),
		ol(
			[],
			[
				li(
					[],
					[
						text("A tag in "),
						code([], [text("Route.Route")]),
						text(", with its arms in "),
						code([], [text("parse")]),
						text(" and "),
						code([], [text("to_path")]),
						text("."),
					],
				),
				li(
					[],
					[
						text("Decide its shape, from Bundles: a page in an app that is one bundle, like Shelf; a bundle of its own; or a page the server renders with islands on it."),
					],
				),
				li(
					[],
					[
						text("For the first two: "),
						code([], [text("shared/Page/<Resource>/<Action>.roc")]),
						text(" with the page's model, messages, view and endpoints, and its line in "),
						code([], [text("shared/main.roc")]),
						text(". For a server-rendered page: nothing here."),
					],
				),
				li(
					[],
					[
						code([], [text("server/Page/<Resource>/<Action>.roc")]),
						text(" with the handler that builds the model and sends it, its endpoints' handlers, and its row in the routing table. A server-rendered page keeps its view here too, and builds each island's model with that island's "),
						code([], [text("new")]),
						text("."),
					],
				),
				li(
					[],
					[
						text("For the first two: "),
						code([], [text("client/Page/<Resource>/<Action>.roc")]),
						text(" with "),
						code([], [text("init")]),
						text(", "),
						code([], [text("update")]),
						text(" and "),
						code([], [text("subscriptions")]),
						text(". In a one-bundle app, its tags in the app's model and messages and its rows in the app's matches. As its own bundle, "),
						code([], [text("./joy new bundle client/<name>.roc")]),
						text(". A running "),
						code([], [text("./joy dev")]),
						text(" sees the new file and adds its tag to "),
						code([], [text("generated/Bundle.roc")]),
						text(", and so does the next "),
						code([], [text("./joy build")]),
						text("."),
					],
				),
				li([], [text("An entry in the menu if it needs one.")]),
			],
		),
		p(
			[],
			[
				text("Try it on Shelf: add an author page at "),
				code([], [text("Page/Authors/Show.roc")]),
				text(" and let the compiler walk you through the rest."),
			],
		),
		h2([], [text("Questions to ask about a new piece of UI")]),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead([], [tr([], [th([], [text("If it")]), th([], [text("then")])])]),
						tbody(
							[],
							[
								tr(
									[],
									[
										td([], [text("never changes")]),
										td([], [text("make it a value, "), code([], [text("Html(msg)")])]),
									],
								),
								tr(
									[],
									[
										td([], [text("shows data but sends nothing")]),
										td([], [text("make it a function of that data")]),
									],
								),
								tr(
									[],
									[
										td([], [text("reacts, with the state kept by the page")]),
										td([], [text("pass it the messages to send")]),
									],
								),
								tr(
									[],
									[
										td([], [text("has state and real logic, and several pages use it")]),
										td([], [text("give it its own model, messages and update")]),
									],
								),
								tr(
									[],
									[
										td([], [text("is used on one page only")]),
										td([], [text("keep it in that page")]),
									],
								),
								tr(
									[],
									[
										td([], [text("has its own state and sits on a page that is otherwise static")]),
										td([], [text("make it an island, a bundle of its own")]),
									],
								),
								tr(
									[],
									[
										td([], [text("is a page that is interactive through most of its area")]),
										td([], [text("make the page a bundle of its own")]),
									],
								),
								tr(
									[],
									[
										td([], [text("is a page that is mostly text")]),
										td([], [text("render it on the server and place islands")]),
									],
								),
							],
						),
					],
				),
			],
		),
	]
}
