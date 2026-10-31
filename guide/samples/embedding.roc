app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import html.Html
import html.Attribute exposing [on_click]
import pf.Effect

Counter := [].{
	Model : { count : I64 }

	Msg : [Bump]

	update : Model, Msg -> (Model, List(Effect(Msg)))
	update = |model, Bump| ({ count: model.count + 1 }, [])

	view : Model -> Html(Msg)
	view = |model| Html.button([on_click(Bump)], [Html.text(model.count.to_str())])
}

Model : { counter : Counter.Model }

Msg : [Counter(Counter.Msg)]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ counter: { count: 0 } }, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, Counter(msg)| {
	(counter, effects) = Counter.update(model.counter, msg)
	wrapped =
		effects.map(|effect| Effect.map(effect, |m| Counter(m)))
	({ counter: counter }, wrapped)
}

view : Model -> Html(Msg)
view = |model|
	Html.map(Counter.view(model.counter), |m| Counter(m))
