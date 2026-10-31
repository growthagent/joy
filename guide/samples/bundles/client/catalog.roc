app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../../../platform/main.roc",
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
	shared: "../shared/main.roc",
}

import /Page/Books/Index as Client
import shared.PageBooksIndex

Model : PageBooksIndex.Model
Msg : PageBooksIndex.Msg

init = |json|
	match Json.parse(json) {
		Ok(model) => Client.init(model)
		Err(e) => crash "Could not read the model: ${Str.inspect(e)}"
	}
update = |model, msg| Client.update(model, msg)
view = |model| PageBooksIndex.view(model)
subscriptions = |model| Client.subscriptions(model)
