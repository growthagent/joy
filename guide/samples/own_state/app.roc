app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import ContactForm
import Listing
import Route
import Update
import html.Html exposing [button, div, text]
import html.Attribute exposing [on_click]
import pf.Effect

Model : { listing : Listing, contact_form : ContactForm.Model }

Msg : [UserClickedFavorite, ContactForm(ContactForm.Msg)]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ listing: Listing.new, contact_form: ContactForm.new({ posts_to: Contact }) }, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, msg|
	match msg {
		UserClickedFavorite => (model, [])

		# in the page's update:
		ContactForm(form_msg) =>
			Update.map(ContactForm.update(model.contact_form, form_msg), |form| { ..model, contact_form: form }, |m| ContactForm(m))
	}

view : Model -> Html(Msg)
view = |model|
	div([], [button([on_click(UserClickedFavorite)], [text(Route.to_path(model.contact_form.posts_to))])])
