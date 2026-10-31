import html.Html exposing [code, h1, h2, p, text]
import html.Attribute exposing [class]
import /Doc

## The topic "Narrow types".
NarrowTypes := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Structuring for scale")]),
		h1([], [text("Narrow types")]),
		p(
			[class("lead")],
			[
				text("As an app grows, the way to keep it understandable is to keep less in your head. Functions that take only what they need, and return only what they change, do that for you."),
			],
		),
		h2([], [text("Take only what you need")]),
		Doc.sketch(
			Roc,
			"",
			\\# Can read and change anything in the model.
			\\view_header : Model -> Html(Msg)
			\\
			\\# Can only show a user and a count, and sends nothing.
			\\view_header : User, U64 -> Html(msg)
		),
		p(
			[],
			[
				text("The narrow version is easier to reuse, and it helps when debugging. When a field of the model goes wrong, any function whose type does not mention that field cannot be the cause, so you can skip it without reading it."),
			],
		),
		p(
			[],
			[
				text("The same goes for parts of "),
				code([], [text("update")]),
				text(". A helper that changes only an address should take and return an address:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\update_address : AddressMsg, Address -> Address
		),
		p(
			[],
			[
				text("When a page has many messages for one part of it, group them in a union of their own, like "),
				code([], [text("Booking(BookingMsg)")]),
				text(", handled by a function that takes only that part's state. That is only organisation: the booking has no update of its own and stays in the page."),
			],
		),
		h2([], [text("Give ids their own types")]),
		p(
			[],
			[
				text("When a book's id and a loan's id are both "),
				code([], [text("I64")]),
				text(", nothing stops you from passing one where the other belongs. An opaque type makes that a compile error:"),
			],
		),
		Doc.code(
			Roc,
			"BookId.roc",
			\\BookId :: { value : I64 }.{
			\\    from_i64 : I64 -> BookId
			\\    from_i64 = |n| { value: n }
			\\
			\\    to_i64 : BookId -> I64
			\\    to_i64 = |id| id.value
			\\}
		),
		p(
			[],
			[
				text("Outside the module, a "),
				code([], [text("BookId")]),
				text(" can only be made with "),
				code([], [text("from_i64")]),
				text(", and code that wants one cannot be handed a "),
				code([], [text("LoanId")]),
				text(" by mistake. The same works for a URL to post to: take a "),
				code([], [text("Route.Route")]),
				text(", not a "),
				code([], [text("Str")]),
				text(", and only real URLs of the app can be passed in."),
			],
		),
		h2([], [text("Write the types out")]),
		p(
			[],
			[
				text("Annotate the functions other modules call, with real types rather than "),
				code([], [text("_")]),
				text(" holes. The annotation is the documentation readers see first, and it keeps a mistake inside the module that made it instead of surfacing as a confusing error somewhere else."),
			],
		),
	]
}
