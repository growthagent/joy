app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import html.Html exposing [button, text]
import html.Attribute exposing [on_click]
import pf.Effect
import pf.Http

Model : { quote : [NotRequestedYet, Loading, Loaded(Str), Error(Str)] }

Msg : [
	UserRequestedQuote,
	GotQuote(Try(Http.Response, [HttpErr([Timeout, NetworkError])])),
]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ quote: NotRequestedYet }, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |_model, msg|
	match msg {
		UserRequestedQuote =>
			({ quote: Loading }, [Http.get("https://example.com/quote", |result| GotQuote(result))])

		GotQuote(Ok(response)) =>
			({ quote: Loaded(Str.from_utf8_lossy(response.body)) }, [])

		GotQuote(Err(HttpErr(Timeout))) => ({ quote: Error("The request timed out") }, [])
		GotQuote(Err(HttpErr(NetworkError))) => ({ quote: Error("The request never completed") }, [])
	}

view : Model -> Html(Msg)
view = |model|
	match model.quote {
		Loaded(quote) => text(quote)
		Error(problem) => text(problem)
		_ => button([on_click(UserRequestedQuote)], [text("Get a quote")])
	}
