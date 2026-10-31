app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import html.Html exposing [text]
import pf.Effect
import pf.Keyboard
import pf.Sub
import pf.Time

Model : { running : Bool, dialog_open : Bool, now : I64 }

Msg : [Tick(I64), UserPressedEscape]

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ running: True, dialog_open: False, now: 0 }, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, msg|
	match msg {
		Tick(now) => ({ ..model, now }, [])
		UserPressedEscape => ({ ..model, dialog_open: False }, [])
	}

subscriptions : Model -> List(Sub(Msg))
subscriptions = |model| {
	ticking = if model.running [Time.every(1000, |now| Tick(now))] else []
	escape = if model.dialog_open [Keyboard.on_down_keys(["Escape"], |_| UserPressedEscape)] else []
	ticking.concat(escape)
}

view : Model -> Html(Msg)
view = |model| text(model.now.to_str())
