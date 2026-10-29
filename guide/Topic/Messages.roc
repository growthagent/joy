import html.Html exposing [code, h1, p, text]
import html.Attribute exposing [class]
import /Doc

## The topic "Messages are facts".
Messages := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Structuring for scale")]),
		h1([], [text("Messages are facts")]),
		p(
			[class("lead")],
			[
				text("Name a message for what happened, in the past tense, and say who did it. Leave it to "),
				code([], [text("update")]),
				text(" to decide what that means."),
			],
		),
		Doc.code(
			Roc,
			"",
			\\# Commands: says what should happen, which is update's job.
			\\Msg : [SetEmail(Str), Submit, SaveBook]
			\\
			\\# Facts: says what happened.
			\\Msg : [
			\\    UserTypedEmail(Str),
			\\    UserSubmittedBorrow,
			\\    UserPausedTyping,
			\\    ServerAnsweredBorrow(Try(Book.Detail, BorrowError)),
			\\]
		),
		p(
			[],
			[
				text("Facts read well in a log of messages, and one fact can mean different things in different states. A "),
				code([], [text("UserPressedEscape")]),
				text(" can close a dialog when one is open and do nothing otherwise, which a "),
				code([], [text("CloseDialog")]),
				text(" command would not let you say."),
			],
		),
		p(
			[],
			[
				text("A message that wraps a child's messages is named after the child, the same tag the model uses for it: "),
				code([], [text("Counter(Counter.Msg)")]),
				text(" for a page whose model is "),
				code([], [text("Counter(Counter.Model)")]),
				text(", "),
				code([], [text("ContactForm(ContactForm.Msg)")]),
				text(" for a form kept in "),
				code([], [text("contact_form")]),
				text(". Roc lets two unions share a tag, so a page has one name wherever it appears."),
			],
		),
	]
}
