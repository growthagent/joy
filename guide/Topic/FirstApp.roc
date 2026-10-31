import html.Html exposing [code, div, h1, h2, p, strong, table, tbody, td, text, th, thead, tr]
import html.Attribute exposing [class]
import /Doc

## The topic "Your first app".
FirstApp := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Start here")]),
		h1([], [text("Your first app")]),
		p(
			[class("lead")],
			[
				text("A Joy app is one Roc file that names its platform and provides six things: "),
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
				text("."),
			],
		),
		h2([], [text("The header")]),
		p(
			[],
			[
				text("The first lines say which platform the app runs on and which packages it uses. Every Joy app needs Joy's platform as "),
				code([], [text("pf")]),
				text(" and joy-html as "),
				code([], [text("html")]),
				text("."),
			],
		),
		Doc.code(
			Roc,
			"client/counter.roc",
			\\app [Model, Msg, init, update, view, subscriptions] {
			\\    pf: platform "https://github.com/niclas-ahden/joy/releases/download/VERSION/HASH.tar.zst",
			\\    html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
			\\}
		),
		p(
			[],
			[
				text("Take the platform URL from the latest release on the Joy releases page. The examples inside the Joy repository use "),
				code([], [text("pf: platform \"../platform/main.roc\"")]),
				text(" instead, so they build against the checkout."),
			],
		),
		h2([], [text("A counter")]),
		Doc.code(
			Roc,
			"client/counter.roc",
			\\import html.Html exposing [div, button, text]
			\\import html.Attribute exposing [id, on_click]
			\\import pf.Effect
			\\
			\\Model : { count : I64 }
			\\
			\\Msg : [Increment, Decrement]
			\\
			\\subscriptions = |_model| []
			\\
			\\init : Str -> (Model, List(Effect(Msg)))
			\\init = |_flags| ({ count: 0 }, [])
			\\
			\\update : Model, Msg -> (Model, List(Effect(Msg)))
			\\update = |model, msg|
			\\    match msg {
			\\        Increment => ({ count: model.count + 1 }, [])
			\\        Decrement => ({ count: model.count - 1 }, [])
			\\    }
			\\
			\\view : Model -> Html(Msg)
			\\view = |model|
			\\    div(
			\\        [],
			\\        [
			\\            button([id("increment"), on_click(Increment)], [text("+")]),
			\\            text(model.count.to_str()),
			\\            button([id("decrement"), on_click(Decrement)], [text("-")]),
			\\        ],
			\\    )
		),
		h2([], [text("The six parts")]),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead([], [tr([], [th([], [text("Part")]), th([], [text("What it is")])])]),
						tbody(
							[],
							[
								tr(
									[],
									[
										td([], [code([], [text("Model")])]),
										td([], [text("Everything the app knows. Here a single count.")]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("Msg")])]),
										td([], [text("Everything that can happen, as a tag union. Here two buttons.")]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("init")])]),
										td(
											[],
											[
												text("The first model, and any effects to start with. It receives the app's flags as a string (see Flags)."),
											],
										),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("update")])]),
										td([], [text("The next model after a message, and the effects to run.")]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("view")])]),
										td([], [text("The page for a model. It is called again after every update.")]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("subscriptions")])]),
										td(
											[],
											[
												text("The outside events the app wants to hear about right now, like a timer. Here none."),
											],
										),
									],
								),
							],
						),
					],
				),
			],
		),
		p(
			[],
			[
				code([], [text("update")]),
				text(" and "),
				code([], [text("view")]),
				text(" are plain functions. They read their arguments and return values, and they cannot fetch data, start timers or touch the DOM. Anything like that is an effect: a value "),
				code([], [text("update")]),
				text(" returns and Joy carries out. That one rule is why a Joy app is easy to follow. To know how the app got into a state, you only need to look at the messages it received."),
			],
		),
		p(
			[],
			[
				text("A file like this one is what Joy calls a "),
				strong([], [text("bundle")]),
				text(": an app on the Joy platform, one file that becomes one wasm. "),
				code([], [text("./joy build")]),
				text(" finds every bundle in "),
				code([], [text("client/")]),
				text(" by that header and builds it, and a page can hold one or several. Bundles, under Growing an app, has the whole of it. For now one file is the whole app."),
			],
		),
		h2([], [text("Running it")]),
		p(
			[],
			[
				text("The page that shows the app is a plain HTML file in "),
				code([], [text("public/")]),
				text(". It has an element that names the bundle and loads "),
				code([], [text("joy.js")]),
				text(", as Flags shows. Then start the development loop:"),
			],
		),
		Doc.code(
			Sh,
			"",
			\\$ ./joy dev
		),
		p(
			[],
			[
				text("The app is now at "),
				code([], [text("http://localhost:8000")]),
				text(". Save "),
				code([], [text("client/counter.roc")]),
				text(" and the open page takes the new build without a reload: the count you clicked up to stays. A build that fails shows roc's report over the page until the next one succeeds. The ./joy command, under Reference, has the rest."),
			],
		),
	]
}
