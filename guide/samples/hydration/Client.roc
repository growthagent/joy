import Shared
import pf.Effect

Client := [].{
	## Elm's init: the model is the flags. It says what the page starts with, here nothing.
	init : Shared.Model -> (Shared.Model, List(Effect(Shared.Msg)))
	init = |model| (model, [])
}
