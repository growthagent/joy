app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import BookId
import html.Html exposing [text]
import pf.Effect

Model : { book : BookId }

Msg : []

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ book: BookId.from_i64(7) }, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, _msg| (model, [])

view : Model -> Html(Msg)
view = |model| text(BookId.to_i64(model.book).to_str())
