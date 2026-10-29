## Every topic of the guide in reading order, and what the index knows of
## each. A topic's body is in Topic/, one module per topic (see Guide).
Topics := [].{
	Topic : [
		Welcome,
		FirstApp,
		Loop,
		Views,
		Effects,
		Subscriptions,
		Flags,
		Pages,
		Fullstack,
		Hydration,
		Bundles,
		Routes,
		Routing,
		Endpoints,
		SimplestApi,
		Partials,
		OwnState,
		StateTypes,
		NarrowTypes,
		Messages,
		Modules,
		AddAPage,
		JoyCli,
		Reading,
	]

	## What the index shows of a topic, and finds it by: its #anchor, the part
	## of the guide it is in, its title and the words a search matches.
	Info : { id : Str, part : Str, title : Str, keywords : Str }

	all : List(Topic)
	all = [
		Welcome,
		FirstApp,
		Loop,
		Views,
		Effects,
		Subscriptions,
		Flags,
		Pages,
		Fullstack,
		Hydration,
		Bundles,
		Routes,
		Routing,
		Endpoints,
		SimplestApi,
		Partials,
		OwnState,
		StateTypes,
		NarrowTypes,
		Messages,
		Modules,
		AddAPage,
		JoyCli,
		Reading,
	]

	info : Topic -> Info
	info = |topic|
		match topic {
			Welcome => { id: "welcome", part: "Start here", title: "What is Joy?", keywords: "intro overview roc wasm webassembly elm architecture platform runtime" }
			FirstApp => { id: "first-app", part: "Start here", title: "Your first app", keywords: "header app counter model msg init update view render subscriptions platform" }
			Loop => { id: "loop", part: "Start here", title: "The update loop", keywords: "elm architecture tea cycle update view render effects messages flow" }
			Views => { id: "views", part: "Start here", title: "Views", keywords: "html attribute joy-html events on_click on_input map inert msg" }
			Effects => { id: "effects", part: "Start here", title: "Effects", keywords: "http time debounce dom modal title scroll clipboard console port webcrypto media effect map" }
			Subscriptions => { id: "subscriptions", part: "Start here", title: "Subscriptions", keywords: "sub time every keyboard on_down_keys listen map" }
			Flags => { id: "flags", part: "Start here", title: "Flags", keywords: "flags init mount json parse javascript start data" }
			Pages => { id: "pages", part: "Growing an app", title: "Pages", keywords: "pages spa page module html map effect map sub map routing model union" }
			Fullstack => { id: "fullstack", part: "Growing an app", title: "Three folders: shared, client, server", keywords: "fullstack full-stack shared client server folders package import path layout effect sub rule" }
			Hydration => { id: "hydration", part: "Growing an app", title: "Server rendering and hydration", keywords: "ssr server rendering hydration model travels json data-joy-flags mount hydrate init encodable dec f64 parser_for" }
			Bundles => { id: "bundles", part: "Growing an app", title: "Bundles", keywords: "bundle island spa per page joy build dev loader joy.js data-joy-bundle Html.bundle Html.document hints preload Bundle.path generated package hydrate mount output dist size server view" }
			Routes => { id: "routes", part: "Growing an app", title: "One type for every URL", keywords: "route routes url parse to_path links tag union" }
			Routing => { id: "routing", part: "Growing an app", title: "The routing table", keywords: "routing table server get api raw handlers access level route match" }
			Endpoints => { id: "endpoints", part: "Growing an app", title: "Typed endpoints", keywords: "api endpoint json errors status server failure apiclient apiserver handler try" }
			SimplestApi => { id: "simplest-api", part: "Structuring for scale", title: "Pick the simplest API", keywords: "reuse api ladder component helper function teach me how to message scaling feldman" }
			Partials => { id: "partials", part: "Structuring for scale", title: "Partials", keywords: "partial view reuse menu header messages as arguments footer" }
			OwnState => { id: "own-state", part: "Structuring for scale", title: "Pieces with their own state", keywords: "component components widget state embed host page outcome close parent child update init new island" }
			StateTypes => { id: "state-types", part: "Structuring for scale", title: "State as types", keywords: "impossible states tag union status booleans single source of truth model data" }
			NarrowTypes => { id: "narrow-types", part: "Structuring for scale", title: "Narrow types", keywords: "narrow types opaque ids keep less in your head arguments annotations" }
			Messages => { id: "messages", part: "Structuring for scale", title: "Messages are facts", keywords: "messages naming past tense facts user server wrapper tags msg" }
			Modules => { id: "modules", part: "Structuring for scale", title: "Organizing modules", keywords: "modules files life of a file headings flat structure type folders organization" }
			AddAPage => { id: "add-a-page", part: "Reference", title: "Adding a page", keywords: "checklist add page new page steps route routing table bundle island joy new bundle server view" }
			JoyCli => { id: "joy-cli", part: "Reference", title: "The ./joy command", keywords: "joy cli command build dev hot reload server new bundle use doctor versions release install dist public assets out-dir port host test ci no-input proxy hash cache json names" }
			Reading => { id: "reading", part: "Reference", title: "Further reading", keywords: "links talks feldman evan elm roc joy examples resources" }
		}

	## Where a topic is in reading order, counting from 0.
	position : Topic -> U64
	position = |topic| {
		var $at = 0
		var $found = 0
		for t in all {
			if t == topic {
				$found = $at
			} else {
				{}
			}
			$at = $at + 1
		}
		$found
	}

	## The topic just before or after this one.
	neighbour : Topic, [Before, After] -> Try(Topic, [NoNeighbour])
	neighbour = |topic, side| {
		at = position(topic)
		match side {
			Before => if (at == 0) Err(NoNeighbour) else all.get(at - 1).map_err(|_| NoNeighbour)
			After => all.get(at + 1).map_err(|_| NoNeighbour)
		}
	}
}
