app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import html.Html exposing [text]
import pf.Effect

Contact : { name : Str, email : Str, consent : Bool }

AddressMsg : [StreetChanged(Str)]

Address : { street : Str }

Model : { contact : Contact, address : Address }

Msg : [Address(AddressMsg)]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ contact: { name: "", email: "", consent: False }, address: { street: "" } }, [])

is_valid_email : Str -> Bool
is_valid_email = |email| email.contains("@")

is_complete : Contact -> Bool
is_complete = |c| !Str.is_empty(c.name) and is_valid_email(c.email) and c.consent

update_address : AddressMsg, Address -> Address
update_address = |StreetChanged(street), _address| { street: street }

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, Address(msg)| ({ ..model, address: update_address(msg, model.address) }, [])

view : Model -> Html(Msg)
view = |model| text(if is_complete(model.contact) "ready" else model.address.street)
