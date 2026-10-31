app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import Client
import Shared
import html.Html exposing [text]
import pf.Effect

Model : Shared.Model

Msg : Shared.Msg

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |flags|
	match Json.parse(flags) {
		Ok(model) => Client.init(model)
		Err(e) => crash "Could not read the model: ${Str.inspect(e)}"
	}

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, Bump| ({ count: model.count + 1 }, [])

view : Model -> Html(Msg)
view = |model| text(model.count.to_str())
