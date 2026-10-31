app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import Clock
import Counter
import Update
import html.Html
import pf.Effect

Model : [
	Counter(Counter.Model),
	Clock(Clock.Model),
]

Msg : [
	Counter(Counter.Msg),
	Clock(Clock.Msg),
]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_flags| Update.map(Counter.init({}), |x| Counter(x), |x| Counter(x))

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, msg|
	match (model, msg) {
		(Counter(c), Counter(m)) => Update.map(Counter.update(c, m), |x| Counter(x), |x| Counter(x))
		(Clock(c), Clock(m)) => Update.map(Clock.update(c, m), |x| Clock(x), |x| Clock(x))

		# A message for a page that is no longer showing, like a late timer.
		_ => (model, [])
	}

view : Model -> Html(Msg)
view = |model|
	match model {
		Counter(c) => Html.map(Counter.view(c), |x| Counter(x))
		Clock(c) => Html.map(Clock.view(c), |x| Clock(x))
	}
