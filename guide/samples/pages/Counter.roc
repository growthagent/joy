import html.Html exposing [button, div, text]
import html.Attribute exposing [on_click]
import pf.Effect
import pf.Sub

Counter := [].{
	Model : { count : I64 }

	Msg : [UserClickedIncrement, UserClickedDecrement]

	init : {} -> (Model, List(Effect(Msg)))
	init = |_| ({ count: 0 }, [])

	update : Model, Msg -> (Model, List(Effect(Msg)))
	update = |model, msg|
		match msg {
			UserClickedIncrement => ({ count: model.count + 1 }, [])
			UserClickedDecrement => ({ count: model.count - 1 }, [])
		}

	subscriptions : Model -> List(Sub(Msg))
	subscriptions = |_model| []

	view : Model -> Html(Msg)
	view = |model|
		div([], [
			button([on_click(UserClickedDecrement)], [text("-")]),
			text(model.count.to_str()),
			button([on_click(UserClickedIncrement)], [text("+")]),
		])
}
