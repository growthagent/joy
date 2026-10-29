import html.Html exposing [code, h1, li, p, strong, text, ul]
import html.Attribute exposing [class]
import /Doc

## The topic "Organizing modules".
Modules := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Structuring for scale")]),
		h1([], [text("Organizing modules")]),
		p(
			[class("lead")],
			[
				text("Build each module around a type, keep the tree flat, and use headings inside a module instead of splitting it into many files."),
			],
		),
		ul(
			[],
			[
				li(
					[],
					[
						strong([], [text("Start in one file.")]),
						text(" Evan Czaplicki's talk The Life of a File shows how a module grows: add to it until a type with its own functions clearly emerges, then move that type and its functions into a module of their own."),
					],
				),
				li(
					[],
					[
						strong([], [text("A module is a type and its functions.")]),
						text(" "),
						code([], [text("Book.roc")]),
						text(" has the book types and the rules about books. "),
						code([], [text("Route.roc")]),
						text(" has the routes. Name modules after what they are about, not after what kind of code they hold."),
					],
				),
				li(
					[],
					[
						strong([], [text("Long files are fine.")]),
						text(" In Roc, as in Elm, the compiler makes it safe to move code around later, so a 600-line module is not a problem by itself. Split when there is a type to split out, not to make files shorter."),
					],
				),
				li(
					[],
					[
						strong([], [text("Use headings.")]),
						text(" A comment heading is enough to organise a module, the way a document has sections."),
					],
				),
			],
		),
		Doc.code(
			Roc,
			"",
			\\# Model
			\\
			\\# View
			\\
			\\# Form
			\\
			\\# HTTP
		),
		ul(
			[],
			[
				li(
					[],
					[
						strong([], [text("Same path in every folder.")]),
						text(" In a full-stack app a page's three halves sit at the same path in "),
						code([], [text("shared/")]),
						text(", "),
						code([], [text("client/")]),
						text(" and "),
						code([], [text("server/")]),
						text(", so finding one finds them all."),
					],
				),
				li(
					[],
					[
						strong([], [text("A bundle file names modules and holds nothing else.")]),
						text(" It sits at the top of "),
						code([], [text("client/")]),
						text(", or anywhere under it, and delegates every one of its six parts to the modules of a page or another piece with its own state. Logic in a bundle file is logic no other bundle can reuse."),
					],
				),
				li(
					[],
					[
						strong([], [text("Rules both sides check live in shared.")]),
						text(" Shelf's "),
						code([], [text("Book.check_borrower")]),
						text(" runs in the browser before the form is sent, so a mistake shows at once, and again on the server, because a request can come from anywhere. Both say the same words about the same mistake."),
					],
				),
			],
		),
	]
}
