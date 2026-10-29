import html.Html exposing [code, h1, p, text]
import html.Attribute exposing [class]
import /Doc

## The topic "Subscriptions".
Subscriptions := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Start here")]),
		h1([], [text("Subscriptions")]),
		p(
			[class("lead")],
			[
				text("An effect happens once. A subscription keeps sending messages for as long as the app asks for it."),
			],
		),
		p(
			[],
			[
				text("After every update Joy calls "),
				code([], [text("subscriptions")]),
				text(" with the new model. Whatever list it returns is what the app listens to from then on. A subscription you stop returning is stopped."),
			],
		),
		Doc.code(
			Roc,
			"",
			\\import pf.Keyboard
			\\import pf.Sub
			\\import pf.Time
			\\
			\\subscriptions : Model -> List(Sub(Msg))
			\\subscriptions = |model| {
			\\    ticking = if model.running [Time.every(1000, |now| Tick(now))] else []
			\\    escape = if model.dialog_open [Keyboard.on_down_keys(["Escape"], |_| UserPressedEscape)] else []
			\\    ticking.concat(escape)
			\\}
		),
		p(
			[],
			[
				text("The clock ticks only while "),
				code([], [text("running")]),
				text(" is true, and Escape is only heard while the dialog is open. Because subscriptions follow the model, they can never get out of step with it. The same holds for the microphone in "),
				code([], [text("pf.Media")]),
				text(": it is open exactly while the app subscribes to it."),
			],
		),
		p(
			[],
			[
				code([], [text("Sub.map")]),
				text(" wraps a subscription's messages, the same way "),
				code([], [text("Html.map")]),
				text(" and "),
				code([], [text("Effect.map")]),
				text(" do."),
			],
		),
	]
}
