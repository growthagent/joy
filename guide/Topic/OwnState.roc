import html.Html exposing [code, h1, h2, li, p, strong, text, ul]
import html.Attribute exposing [class]
import /Doc

## The topic "Pieces with their own state".
OwnState := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Structuring for scale")]),
		h1([], [text("Pieces with their own state")]),
		p(
			[class("lead")],
			[
				text("A piece of UI can have its own model, messages and update, and be used inside pages or placed on them as an island. Think of it as a page without a URL. It is the top step of the ladder, so take it only when the steps below fall short."),
			],
		),
		p(
			[],
			[
				text("Other frameworks call this a component. Joy has no name or folder for it, because it is not a kind of thing. It is a few modules shaped like a page and named after what they are about, like "),
				code([], [text("ContactForm")]),
				text(". A name would make it a category that every piece of UI seems to belong in."),
			],
		),
		h2([], [text("When it pays off")]),
		p(
			[],
			[
				text("A contact form shown on many pages is the typical case. It has several fields with validation, a submit that sends a request, and success and error states. Without its own "),
				code([], [text("Msg")]),
				text(" and "),
				code([], [text("update")]),
				text(", every page that shows it would need all those messages and all that logic. With them, each page keeps one field and one message tag, or places it as an island and keeps nothing. Feldman's elm-spa-example does the same for its article feed, used on two pages and with six messages of its own."),
			],
		),
		p(
			[],
			[
				text("It does not pay off for something used on one page. Keep that inside the page. It also does not pay off for something with one or two messages and little logic. Give it the messages as arguments instead."),
			],
		),
		h2([], [text("Its shape")]),
		p(
			[],
			[
				text("It has the same halves as a page, at the same path in each folder, plus a bundle when it is an island:"),
			],
		),
		Doc.code(
			Text,
			"",
			\\shared/ContactForm.roc     Model, Msg, new, view, island, its endpoint
			\\client/ContactForm.roc     init, update, subscriptions
			\\server/ContactForm.roc     the handler of its endpoint
			\\client/contact_form.roc    its bundle, when it is an island
		),
		p(
			[],
			[
				text("What differs between two uses goes into "),
				code([], [text("new")]),
				text(", like where the form posts, and stays in the model. The server, or the page that embeds the form, builds it with "),
				code([], [text("new")]),
				text(". Then "),
				code([], [text("init")]),
				text(" says what it starts with and "),
				code([], [text("update")]),
				text(" takes the model and the message and nothing else:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\new : { posts_to : Route.Route } -> Model
			\\
			\\init : Model -> (Model, List(Effect(Msg)))
			\\
			\\update : Model, Msg -> (Model, List(Effect(Msg)))
		),
		h2([], [text("Embedded in a page")]),
		p(
			[],
			[
				text("A page that is a bundle keeps the form's model in one field and wraps its messages in one tag named after it:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\Model : { listing : Listing, contact_form : ContactForm.Model }
			\\
			\\Msg : [UserClickedFavorite, ContactForm(ContactForm.Msg)]
		),
		p(
			[],
			[
				code([], [text("Update.map")]),
				text(", from Pages, puts the form's result back into the page the way it puts a page's result back into the app:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\# in the page's update:
			\\ContactForm(form_msg) =>
			\\    Update.map(ContactForm.update(model.contact_form, form_msg), |form| { ..model, contact_form: form }, |m| ContactForm(m))
		),
		h2([], [text("As an island")]),
		p(
			[],
			[
				text("On a page the server renders, the same form is a bundle of its own. The page keeps nothing of it: the handler builds the form with "),
				code([], [text("new")]),
				text(", the view places it with the form's "),
				code([], [text("island")]),
				text(", and "),
				code([], [text("client/contact_form.roc")]),
				text(" runs it in the browser. Its halves are the same either way, and the choice is the page's: embedded when the page is a bundle, an island when the page is text with the form on it. Bundles has the whole picture, including why a dialog island owns its own button."),
			],
		),
		h2([], [text("Telling the page something")]),
		p(
			[],
			[
				text("Sometimes a page that embeds a piece like this has to react to what happened inside it. Say the form sits in a dialog that the page owns, and the form's \"No thanks\" button should close it. Let "),
				code([], [text("update")]),
				text(" return what the page needs to know:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\update : Model, Msg -> (Model, List(Effect(Msg)), [Stay, Close])
			\\
			\\# in the page:
			\\ContactForm(form_msg) => {
			\\    (form, effects, outcome) = ContactForm.update(model.contact_form, form_msg)
			\\    closing =
			\\        match outcome {
			\\            Close => [DOM.close_modal("#contact")]
			\\            Stay => []
			\\        }
			\\    ({ ..model, contact_form: form }, effects.map(|e| e.map(|m| ContactForm(m))).concat(closing))
			\\}
		),
		p([], [text("Two other ways show up in real code and age badly:")]),
		ul(
			[],
			[
				li(
					[],
					[
						strong([], [text("The page matches the form's own messages")]),
						text(", like "),
						code([], [text("ContactForm(Closed)")]),
						text(". Now the page depends on how the form is built inside, and a renamed message breaks it."),
					],
				),
				li(
					[],
					[
						strong([], [text("Configuration that says one thing while the page does another.")]),
						text(" If the form is told in "),
						code([], [text("new")]),
						text(" that it closes its own dialog, but the page catches that message first, the configuration is never read and misleads the next reader."),
					],
				),
			],
		),
		p(
			[],
			[
				text("A returned outcome is part of the form's API, in its type, and the compiler checks every page that uses it. As an island the question does not arise: the island owns its dialog and closes it itself."),
			],
		),
	]
}
