import html.Html exposing [code, div, h1, h2, h3, li, ol, p, span, strong, text, ul]
import html.Attribute exposing [class]
import /Doc

## The topic "Pick the simplest API".
SimplestApi := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Structuring for scale")]),
		h1([], [text("Pick the simplest API")]),
		p(
			[class("lead")],
			[
				text("When a piece of UI shows up in more than one place, first ask what its API should look like. Then pick the simplest one that does the job."),
			],
		),
		p(
			[],
			[
				text("This is the central idea of Richard Feldman's talk Scaling Elm Apps, and it holds for Joy the same way. There is a ladder of APIs, from simple to heavy. Each step up costs more to use, so climb only as far as you need."),
			],
		),
		ol(
			[class("ladder")],
			[
				li(
					[],
					[
						span([class("rung")], [text("1")]),
						div(
							[],
							[
								h3([], [text("A value")]),
								p([], [text("Nothing changes from one use to the next.")]),
								Doc.code(
									Roc,
									"",
									\\subscribe_button : Html(Msg)
									\\subscribe_button = a([class("button"), href(Route.to_path(Subscribe))], [text("Subscribe")])
								),
							],
						),
					],
				),
				li(
					[],
					[
						span([class("rung")], [text("2")]),
						div(
							[],
							[
								h3([], [text("A function of data")]),
								p([], [text("It shows different things, but does nothing on its own.")]),
								Doc.code(
									Roc,
									"",
									\\badge : User -> Html(msg)
									\\badge = |user| span([class("badge")], [text(user.name)])
								),
							],
						),
					],
				),
				li(
					[],
					[
						span([class("rung")], [text("3")]),
						div(
							[],
							[
								h3([], [text("Teach it how to message")]),
								p(
									[],
									[
										text("It reacts to the user, and the caller says which message to send. The caller keeps the state."),
									],
								),
								Doc.code(
									Roc,
									"",
									\\checkbox : { label : Str, checked : Bool, toggled : msg } -> Html(msg)
									\\checkbox = |{ label: words, checked: is_checked, toggled }|
									\\    Html.label([], [
									\\        input([type("checkbox"), checked(is_checked), on_click(toggled)]),
									\\        text(words),
									\\    ])
								),
							],
						),
					],
				),
				li(
					[],
					[
						span([class("rung")], [text("4")]),
						div(
							[],
							[
								h3([], [text("Its own model, messages and update")]),
								p(
									[],
									[
										text("It has state of its own and several messages with real logic behind them, and you would otherwise repeat all of that on every page that uses it."),
									],
								),
								Doc.sketch(
									Roc,
									"",
									\\ContactForm.Model, ContactForm.Msg, ContactForm.init, ContactForm.view   # shared
									\\ContactForm.update                                                   # client
								),
							],
						),
					],
				),
			],
		),
		h2([], [text("Why not make everything a component")]),
		p(
			[],
			[
				text("Coming from React or object-oriented UI, it is tempting to give every piece of the page its own model, messages and update, so they all look alike. Feldman tried that early on and was unhappy with it, and so were many others. It goes wrong in three ways:"),
			],
		),
		ul(
			[],
			[
				li(
					[],
					[
						strong([], [text("It splits the truth.")]),
						text(" Give every dropdown its own "),
						code([], [text("open : Bool")]),
						text(" and two of them can be open at once, though the design says only one may be. Store "),
						code([], [text("open_dropdown : [NoDropdown, Open(DropdownId)]")]),
						text(" in the page instead, and the bug cannot be written."),
					],
				),
				li(
					[],
					[
						strong([], [text("It widens every type.")]),
						text(" A button that could be "),
						code([], [text("Html(msg)")]),
						text(" now needs an init, a message type, an update branch in every page and a "),
						code([], [text("Html.map")]),
						text("."),
					],
				),
				li(
					[],
					[
						strong([], [text("It needs parent-child plumbing.")]),
						text(" Once state lives in a child, the parent keeps needing pieces of it back, and you write code to pass them up."),
					],
				),
			],
		),
		p(
			[],
			[
				text("Feldman's comparison is a place setting: soup takes a spoon, salad a fork, chicken a fork and a knife. Using every utensil for every dish is not more consistent, only harder. Each piece of UI gets the tool that fits it."),
			],
		),
	]
}
