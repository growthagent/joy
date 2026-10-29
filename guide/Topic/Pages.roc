import html.Html exposing [code, div, h1, h2, li, p, span, strong, text, ul]
import html.Attribute exposing [class]
import /Doc

## The topic "Pages".
Pages := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Growing an app")]),
		h1([], [text("Pages")]),
		p(
			[class("lead")],
			[
				text("When an app grows, split it into pages. A page is a module with its own "),
				code([], [text("Model")]),
				text(", "),
				code([], [text("Msg")]),
				text(", "),
				code([], [text("init")]),
				text(", "),
				code([], [text("update")]),
				text(", "),
				code([], [text("view")]),
				text(" and "),
				code([], [text("subscriptions")]),
				text(". It is the same shape as an app, only the app calls it instead of the platform."),
			],
		),
		Doc.code(
			Roc,
			"Counter.roc",
			\\import html.Html exposing [button, div, text]
			\\import html.Attribute exposing [on_click]
			\\import pf.Effect
			\\import pf.Sub
			\\
			\\Counter := [].{
			\\    Model : { count : I64 }
			\\
			\\    Msg : [UserClickedIncrement, UserClickedDecrement]
			\\
			\\    init : {} -> (Model, List(Effect(Msg)))
			\\    init = |_| ({ count: 0 }, [])
			\\
			\\    update : Model, Msg -> (Model, List(Effect(Msg)))
			\\    update = |model, msg|
			\\        match msg {
			\\            UserClickedIncrement => ({ count: model.count + 1 }, [])
			\\            UserClickedDecrement => ({ count: model.count - 1 }, [])
			\\        }
			\\
			\\    subscriptions : Model -> List(Sub(Msg))
			\\    subscriptions = |_model| []
			\\
			\\    view : Model -> Html(Msg)
			\\    view = |model|
			\\        div([], [
			\\            button([on_click(UserClickedDecrement)], [text("-")]),
			\\            text(model.count.to_str()),
			\\            button([on_click(UserClickedIncrement)], [text("+")]),
			\\        ])
			\\}
		),
		p(
			[],
			[
				text("A module's type is named after its file, so "),
				code([], [text("Counter.roc")]),
				text(" holds "),
				code([], [text("Counter := [].{ ... }")]),
				text(", and other modules refer to "),
				code([], [text("Counter.Model")]),
				text(" and "),
				code([], [text("Counter.update")]),
				text("."),
			],
		),
		h2([], [text("Putting pages together")]),
		p(
			[],
			[
				text("The app's model says which page is showing and holds that page's model. Its messages wrap each page's messages in a tag:"),
			],
		),
		Doc.code(
			Roc,
			"app.roc, after examples/pages",
			\\Model : [
			\\    Counter(Counter.Model),
			\\    Clock(Clock.Model),
			\\]
			\\
			\\Msg : [
			\\    Counter(Counter.Msg),
			\\    Clock(Clock.Msg),
			\\]
			\\
			\\update : Model, Msg -> (Model, List(Effect(Msg)))
			\\update = |model, msg|
			\\    match (model, msg) {
			\\        (Counter(c), Counter(m)) => Update.map(Counter.update(c, m), |x| Counter(x), |x| Counter(x))
			\\        (Clock(c), Clock(m)) => Update.map(Clock.update(c, m), |x| Clock(x), |x| Clock(x))
			\\
			\\        # A message for a page that is no longer showing, like a late timer.
			\\        _ => (model, [])
			\\    }
			\\
			\\view : Model -> Html(Msg)
			\\view = |model|
			\\    match model {
			\\        Counter(c) => Html.map(Counter.view(c), |x| Counter(x))
			\\        Clock(c) => Html.map(Clock.view(c), |x| Clock(x))
			\\    }
		),
		p(
			[],
			[
				text("Matching on the page and the message together means a message can only reach the page it belongs to. A page has one tag, "),
				code([], [text("Counter")]),
				text(", in both unions, which Roc allows, so a row names the page and nothing else, and the two wrappers are the same lambda. "),
				code([], [text("Update.map")]),
				text(" is what makes each row one line. "),
				code([], [text("Html.map")]),
				text(" lifts a page's view into the app's messages, "),
				code([], [text("Effect.map")]),
				text(" and "),
				code([], [text("Sub.map")]),
				text(" do it for an effect and a subscription, and "),
				code([], [text("Update.map")]),
				text(" does it for what "),
				code([], [text("update")]),
				text(" returns, the model with its effects. It is a few lines you write once:"),
			],
		),
		Doc.code(
			Roc,
			"Update.roc",
			\\## What a page's `update` returns, in the app's types: its model in the
			\\## page's tag, its effects' messages in the page's message tag.
			\\Update := [].{
			\\    map : (page, List(Effect(page_msg))), (page -> host), (page_msg -> host_msg) -> (host, List(Effect(host_msg)))
			\\    map = |(page, effects), to_model, to_msg| (to_model(page), effects.map(|e| e.map(to_msg)))
			\\}
		),
		p(
			[],
			[
				text("The two wrappers are lambdas because a Roc tag is not a function: a bare "),
				code([], [text("Counter")]),
				text(" passed as an argument is the tag with no payload, not a constructor."),
			],
		),
		h2([], [text("Two ways to switch pages")]),
		ul(
			[],
			[
				li(
					[],
					[
						strong([], [text("One URL per page")]),
						text(" ("),
						code([], [text("examples/pages")]),
						text("). Links are ordinary links, the browser loads the next page, and the model only holds the page on screen. This is the shape of a server-rendered app."),
					],
				),
				li(
					[],
					[
						strong([], [text("Switching in place")]),
						text(" ("),
						code([], [text("examples/spa_pages")]),
						text("). The app keeps every page's model and changes which one it shows, without a page load."),
					],
				),
			],
		),
		p(
			[],
			[
				text("The page modules are the same in both. Only the app module differs, which makes the two examples easy to compare."),
			],
		),
		p(
			[],
			[
				text("Both keep every page in one bundle, which a visitor downloads whole. That is right while the app is small. When it is not, a page can be a bundle of its own, or a server-rendered page with small bundles on it, with the same page modules. Bundles covers that."),
			],
		),
		div(
			[class("note")],
			[
				span([class("note-label")], [text("Why pages get their own model")]),
				text(" "),
				p(
					[],
					[
						text("A page is the clearest case where its own model, messages and update pay off: pages have real state of their own and rarely share it. Do not take this as a pattern for everything else in an app. The section on picking the simplest API explains why."),
					],
				),
			],
		),
	]
}
