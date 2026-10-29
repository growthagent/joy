import /Topic/Welcome as TopicWelcome
import /Topic/FirstApp as TopicFirstApp
import /Topic/Loop as TopicLoop
import /Topic/Views as TopicViews
import /Topic/Effects as TopicEffects
import /Topic/Subscriptions as TopicSubscriptions
import /Topic/Flags as TopicFlags
import /Topic/Pages as TopicPages
import /Topic/Fullstack as TopicFullstack
import /Topic/Hydration as TopicHydration
import /Topic/Bundles as TopicBundles
import /Topic/Routes as TopicRoutes
import /Topic/Routing as TopicRouting
import /Topic/Endpoints as TopicEndpoints
import /Topic/SimplestApi as TopicSimplestApi
import /Topic/Partials as TopicPartials
import /Topic/OwnState as TopicOwnState
import /Topic/StateTypes as TopicStateTypes
import /Topic/NarrowTypes as TopicNarrowTypes
import /Topic/Messages as TopicMessages
import /Topic/Modules as TopicModules
import /Topic/AddAPage as TopicAddAPage
import /Topic/JoyCli as TopicJoyCli
import /Topic/Reading as TopicReading
import html.Html
import /Doc
import /Topics

## A topic's body, from its module in Topic/.
Guide := [].{
	body : Topics.Topic -> Doc.Body
	body = |topic|
		match topic {
			Welcome => TopicWelcome.body
			FirstApp => TopicFirstApp.body
			Loop => TopicLoop.body
			Views => TopicViews.body
			Effects => TopicEffects.body
			Subscriptions => TopicSubscriptions.body
			Flags => TopicFlags.body
			Pages => TopicPages.body
			Fullstack => TopicFullstack.body
			Hydration => TopicHydration.body
			Bundles => TopicBundles.body
			Routes => TopicRoutes.body
			Routing => TopicRouting.body
			Endpoints => TopicEndpoints.body
			SimplestApi => TopicSimplestApi.body
			Partials => TopicPartials.body
			OwnState => TopicOwnState.body
			StateTypes => TopicStateTypes.body
			NarrowTypes => TopicNarrowTypes.body
			Messages => TopicMessages.body
			Modules => TopicModules.body
			AddAPage => TopicAddAPage.body
			JoyCli => TopicJoyCli.body
			Reading => TopicReading.body
		}
}
