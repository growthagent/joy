app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
}

import Route
import html.Html exposing [a, input, span, text]
import html.Attribute exposing [checked, class, href, on_click, type]
import pf.Effect

User : { name : Str }

Model : { user : User, agreed : Bool }

Msg : [UserToggled]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ user: { name: "Ada" }, agreed: False }, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, UserToggled| ({ ..model, agreed: !model.agreed }, [])

subscribe_button : Html(Msg)
subscribe_button = a([class("button"), href(Route.to_path(Subscribe))], [text("Subscribe")])

badge : User -> Html(msg)
badge = |user| span([class("badge")], [text(user.name)])

checkbox : { label : Str, checked : Bool, toggled : msg } -> Html(msg)
checkbox = |{ label: words, checked: is_checked, toggled }|
	Html.label([], [
		input([type("checkbox"), checked(is_checked), on_click(toggled)]),
		text(words),
	])

view : Model -> Html(Msg)
view = |model|
	Html.div([], [subscribe_button, badge(model.user), checkbox({ label: "Agree", checked: model.agreed, toggled: UserToggled })])
