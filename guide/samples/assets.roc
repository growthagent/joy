app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import html.Html exposing [link]
import html.Attribute exposing [href, rel]
import pf.Effect

Asset := [Asset(Str)].{
	from_quote : Str -> Try(Asset, [BadQuotedBytes(Str)])
	from_quote = |file| Ok(Asset(file))

	path : Asset -> Str
	path = |Asset(file)| file
}

Model : {}

Msg : []

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({}, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, _msg| (model, [])

client_url : Str
client_url = "/"

asset : Asset -> Str
asset = |file| "${client_url}${Asset.path(file)}"

view : Model -> Html(Msg)
view = |_model|
	link([rel("stylesheet"), href(asset("css/site.css"))])
