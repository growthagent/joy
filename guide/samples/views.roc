app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import html.Html exposing [div, h1, input, label, p, text]
import html.Attribute exposing [class, for_, id, on_input, value]
import pf.Effect

Model : { query : Str }

Msg : [UserTypedQuery(Str)]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ query: "" }, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |_model, msg|
	match msg {
		UserTypedQuery(query) => ({ query: query }, [])
	}

search_box : Str -> Html(Msg)
search_box = |query|
	div(
		[class("search")],
		[
			label([for_("query")], [text("Search")]),
			input([id("query"), value(query), on_input(|typed| UserTypedQuery(typed))]),
		],
	)

## Inert: works on any page, can never send a message.
price_tag : I64 -> Html(msg)
price_tag = |kronor| p([class("price")], [text("${kronor.to_str()} kr")])

view : Model -> Html(Msg)
view = |model| div([], [h1([], [text("Shop")]), search_box(model.query), price_tag(100)])
