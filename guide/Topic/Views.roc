import html.Html exposing [code, h1, h2, li, p, text, ul]
import html.Attribute exposing [class]
import /Doc

## The topic "Views".
Views := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Start here")]),
		h1([], [text("Views")]),
		p(
			[class("lead")],
			[
				text("Views are built with joy-html. An element is a function that takes a list of attributes and a list of children."),
			],
		),
		Doc.code(
			Roc,
			"",
			\\import html.Html exposing [div, h1, input, label, p, text]
			\\import html.Attribute exposing [class, for_, id, on_input, value]
			\\
			\\search_box : Str -> Html(Msg)
			\\search_box = |query|
			\\    div(
			\\        [class("search")],
			\\        [
			\\            label([for_("query")], [text("Search")]),
			\\            input([id("query"), value(query), on_input(|typed| UserTypedQuery(typed))]),
			\\        ],
			\\    )
		),
		p(
			[],
			[
				text("Events are attributes that carry a message. "),
				code([], [text("on_click(UserClickedSave)")]),
				text(" sends a message as it is. "),
				code([], [text("on_input")]),
				text(" and other events that come with a value take a function from the value to a message."),
			],
		),
		h2([], [text("The type tells you what a view can do")]),
		p([], [text("Look at the type a view returns:")]),
		ul(
			[],
			[
				li(
					[],
					[
						code([], [text("Html(Msg)")]),
						text(" can send the messages of "),
						code([], [text("Msg")]),
						text(". It may have buttons, inputs or links that do something."),
					],
				),
				li(
					[],
					[
						code([], [text("Html(msg)")]),
						text(" with a lowercase type variable can send nothing. It works inside any page because it never produces a message of its own. A heading, a price, an error text."),
					],
				),
			],
		),
		Doc.code(
			Roc,
			"",
			\\## Inert: works on any page, can never send a message.
			\\price_tag : I64 -> Html(msg)
			\\price_tag = |kronor| p([class("price")], [text("\${kronor.to_str()} kr")])
		),
		p(
			[],
			[
				text("Use the lowercase form whenever a view has no events. Readers learn something at a glance, and the view can be used on any page without wrapping."),
			],
		),
		h2([], [text("Html.map")]),
		p(
			[],
			[
				text("When a part of the page has its own message type, "),
				code([], [text("Html.map")]),
				text(" wraps every message it sends into a message of the page:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\Html.map(Counter.view(model.counter), |m| Counter(m))
		),
		p(
			[],
			[
				text("You will see this whenever an app is split into pages, in Pages, and when a piece of UI has its own state, in Pieces with their own state."),
			],
		),
	]
}
