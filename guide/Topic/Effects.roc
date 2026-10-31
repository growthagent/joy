import html.Html exposing [code, div, h1, h2, p, table, tbody, td, text, th, thead, tr]
import html.Attribute exposing [class]
import /Doc

## The topic "Effects".
Effects := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Start here")]),
		h1([], [text("Effects")]),
		p(
			[class("lead")],
			[
				text("An effect is a description of something to do: send a request, wait, open a dialog. "),
				code([], [text("update")]),
				text(" returns effects, and Joy runs them."),
			],
		),
		Doc.code(
			Roc,
			"",
			\\import pf.Effect
			\\import pf.Http
			\\
			\\Model : { quote : [NotRequestedYet, Loading, Loaded(Str), Error(Str)] }
			\\
			\\Msg : [
			\\    UserRequestedQuote,
			\\    GotQuote(Try(Http.Response, [HttpErr([Timeout, NetworkError])])),
			\\]
			\\
			\\update : Model, Msg -> (Model, List(Effect(Msg)))
			\\update = |_model, msg|
			\\    match msg {
			\\        UserRequestedQuote =>
			\\            ({ quote: Loading }, [Http.get("https://example.com/quote", |result| GotQuote(result))])
			\\
			\\        GotQuote(Ok(response)) =>
			\\            ({ quote: Loaded(Str.from_utf8_lossy(response.body)) }, [])
			\\
			\\        GotQuote(Err(HttpErr(Timeout))) => ({ quote: Error("The request timed out") }, [])
			\\        GotQuote(Err(HttpErr(NetworkError))) => ({ quote: Error("The request never completed") }, [])
			\\    }
		),
		p(
			[],
			[
				text("The model changes to "),
				code([], [text("Loading")]),
				text(" at once, and the request goes out. When it answers, its result arrives as "),
				code([], [text("GotQuote")]),
				text(". Notice that the quote's state is one tag union, not a loading flag plus an error string. More on that in State as types."),
			],
		),
		h2([], [text("What the platform offers")]),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead([], [tr([], [th([], [text("Module")]), th([], [text("For example")])])]),
						tbody(
							[],
							[
								tr(
									[],
									[
										td([], [code([], [text("pf.Http")])]),
										td(
											[],
											[
												code([], [text("Http.get(url, to_msg)")]),
												text(", "),
												code([], [text("Http.post")]),
												text(", "),
												code([], [text("Http.request")]),
												text(", file uploads"),
											],
										),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("pf.Time")])]),
										td(
											[],
											[
												code([], [text("Time.after(ms, to_msg)")]),
												text(", "),
												code([], [text("Time.debounce(key, ms, to_msg)")]),
												text(", "),
												code([], [text("Time.cancel(key)")]),
											],
										),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("pf.DOM")])]),
										td(
											[],
											[
												code([], [text("DOM.show_modal(\"#confirm\")")]),
												text(", "),
												code([], [text("DOM.close_modal")]),
												text(", "),
												code([], [text("DOM.focus")]),
												text(", "),
												code([], [text("DOM.push_url")]),
												text(", "),
												code([], [text("DOM.replace_url")]),
												text(", "),
												code([], [text("DOM.set_title")]),
												text(", "),
												code([], [text("DOM.scroll_to")]),
											],
										),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("pf.Clipboard")])]),
										td([], [code([], [text("Clipboard.write_text(text, to_msg)")]), text(", "), code([], [text("Clipboard.write_text_of(selector, to_msg)")])]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("pf.Console")])]),
										td([], [code([], [text("Console.log(text)")])]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("pf.Port")])]),
										td([], [text("Sending values to your own JavaScript and hearing back from it")]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("pf.WebCrypto")])]),
										td([], [text("Hashing data and files in the browser")]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("pf.Media")])]),
										td([], [text("Recording from the microphone or camera, playing audio and video")]),
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
				text("Only the browser code of the features your bundles call ends up in "),
				code([], [text("joy.js")]),
				text(", so a site that never records audio does not ship the recording code."),
			],
		),
		h2([], [text("A debounce")]),
		p(
			[],
			[
				text("A search field should not send a request on every keystroke. "),
				code([], [text("Time.debounce")]),
				text(" restarts a named timer each time it is returned, so only the last keystroke in a pause gets through:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\UserTypedQuery(query) =>
			\\    ({ ..model, query }, [Time.debounce("search", 200, |_| UserPausedTyping)])
			\\
			\\UserPausedTyping =>
			\\    (model, [Http.get(search_url(model.query), |result| ServerAnsweredSearch(result))])
		),
		h2([], [text("Effect.map")]),
		p(
			[],
			[
				text("Like "),
				code([], [text("Html.map")]),
				text(", "),
				code([], [text("Effect.map")]),
				text(" changes the message an effect will produce. You need it when a page, or any other piece with its own update, returns effects of its own message type:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\effects.map(|effect| Effect.map(effect, |m| Counter(m)))
		),
	]
}
