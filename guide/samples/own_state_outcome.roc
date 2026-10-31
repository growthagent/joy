app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import html.Html exposing [text]
import pf.DOM
import pf.Effect

ContactForm := [].{
	Model : { sent : Bool }

	Msg : [UserSubmitted]

	update : Model, Msg -> (Model, List(Effect(Msg)), [Stay, Close])
	update = |_model, UserSubmitted| ({ sent: True }, [], Close)
}

Model : { contact_form : ContactForm.Model }

Msg : [ContactForm(ContactForm.Msg)]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ contact_form: { sent: False } }, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, msg|
	match msg {
		# in the page:
		ContactForm(form_msg) => {
			(form, effects, outcome) = ContactForm.update(model.contact_form, form_msg)
			closing =
				match outcome {
					Close => [DOM.close_modal("#contact")]
					Stay => []
				}
			({ ..model, contact_form: form }, effects.map(|e| e.map(|m| ContactForm(m))).concat(closing))
		}
	}

view : Model -> Html(Msg)
view = |model| text(if model.contact_form.sent "sent" else "")
