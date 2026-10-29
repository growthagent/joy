import html.Html exposing [code, div, h1, h2, li, ol, p, span, strong, text, ul]
import html.Attribute exposing [aria, class, role]
import /Doc

## The topic "The update loop".
Loop := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Start here")]),
		h1([], [text("The update loop")]),
		p(
			[class("lead")],
			[
				text("Every Joy app runs the same loop. Knowing it by heart makes every other topic in this guide easier."),
			],
		),
		div(
			[class("loop"), role("img"), aria("label", "The loop: view turns the model into Html, Joy updates the page, an event becomes a message, update returns a new model and effects, and the loop starts over.")],
			[
				span([class("step")], [text("Model")]),
				span([class("arrow")], [text("→")]),
				text(" "),
				span([class("step you")], [text("view(model)")]),
				span([class("arrow")], [text("→")]),
				text(" "),
				span([class("step")], [text("Html(Msg)")]),
				span([class("arrow")], [text("→")]),
				text(" "),
				span([class("step")], [text("Joy updates the page")]),
				span([class("arrow")], [text("→")]),
				text(" "),
				span([class("step")], [text("a click, a keypress, an answer")]),
				span([class("arrow")], [text("→")]),
				text(" "),
				span([class("step")], [text("Msg")]),
				span([class("arrow")], [text("→")]),
				text(" "),
				span([class("step you")], [text("update(model, msg)")]),
				span([class("arrow")], [text("→")]),
				text(" "),
				span([class("step")], [text("(Model, effects)")]),
				span([class("arrow")], [text("↺")]),
			],
		),
		p(
			[class("loop-caption")],
			[
				text("Highlighted steps are the functions you write. Joy does everything else."),
			],
		),
		ol(
			[],
			[
				li(
					[],
					[
						text("Joy calls "),
						code([], [text("view")]),
						text(" with the current model and gets back a tree of "),
						code([], [text("Html(Msg)")]),
						text("."),
					],
				),
				li([], [text("Joy compares it with the last tree and changes only what differs on the page.")]),
				li(
					[],
					[
						text("Something happens: the user clicks a button that carries "),
						code([], [text("on_click(Increment)")]),
						text(", a timer fires, or an HTTP request answers. Each of these becomes a message."),
					],
				),
				li(
					[],
					[
						text("Joy calls "),
						code([], [text("update")]),
						text(" with the model and the message. You return the next model and a list of effects."),
					],
				),
				li(
					[],
					[
						text("Joy runs the effects. When one of them finishes, its result comes back as another message, through step 3."),
					],
				),
			],
		),
		h2([], [text("What follows from it")]),
		ul(
			[],
			[
				li(
					[],
					[
						strong([], [text("One source of truth.")]),
						text(" The page is always "),
						code([], [text("view(model)")]),
						text(". There is no hidden state in the DOM that the model does not know about."),
					],
				),
				li(
					[],
					[
						strong([], [text("Effects are data.")]),
						text(" "),
						code([], [text("update")]),
						text(" describes what should happen. Joy decides when and how. That makes "),
						code([], [text("update")]),
						text(" easy to test: call it and look at what it returns."),
					],
				),
				li(
					[],
					[
						strong([], [text("Messages are the history.")]),
						text(" Every change to the model came from a message, so a list of messages explains how the app got where it is."),
					],
				),
			],
		),
	]
}
