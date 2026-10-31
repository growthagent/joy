import Route
import pf.Effect

ContactForm := [].{
	Model : { posts_to : Route.Route, sent : Bool }

	Msg : [UserSubmitted]

	new : { posts_to : Route.Route } -> Model
	new = |{ posts_to }| { posts_to, sent: False }

	init : Model -> (Model, List(Effect(Msg)))
	init = |model| (model, [])

	update : Model, Msg -> (Model, List(Effect(Msg)))
	update = |model, UserSubmitted| ({ ..model, sent: True }, [])
}
