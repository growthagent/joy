import html.Html exposing [text]
import pf.Effect

Clock := [].{
	Model : { seconds : I64 }

	Msg : [Tick]

	update : Model, Msg -> (Model, List(Effect(Msg)))
	update = |model, Tick| ({ seconds: model.seconds + 1 }, [])

	view : Model -> Html(Msg)
	view = |model| text(model.seconds.to_str())
}
