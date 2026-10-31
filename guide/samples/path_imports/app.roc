app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import /Page/Books/Show as PageBooksShow
import /Book
import html.Html exposing [text]
import pf.Effect

Model : {}

Msg : []

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({}, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, _msg| (model, [])

view : Model -> Html(Msg)
view = |_model| text("${PageBooksShow.title} ${Book.title}")
