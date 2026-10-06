import /Book
import /Page/Books/Show as BooksShow
import /Route
import html.Html exposing [a, button, h1, li, p, section, span, text, ul]
import html.Attribute exposing [class, disabled, href, on_click]

## Every book that is out, at `/loans`, with who borrowed it and a button to
## give it back, and a link to download the list as CSV (`/loans.csv`, served
## by server/Page/Loans/Index.roc). Giving one back uses the book page's endpoint
## (`Show.give_back` in Page/Books/Show.roc): one endpoint, two pages.
##
## The page shows borrowers' emails to anyone who opens it. That is the
## library's desk, and a real app puts it behind a sign-in.
Index := [].{
	Model : { loans : List(Book.Loan), giving_back : GivingBack }

	## One give-back at a time: the button of the book on its way back is
	## disabled, the rest wait their turn.
	GivingBack : [Idle, GivingBack(I64), Failed(Str)]

	Msg : [
		UserClickedGiveBack(I64),
		ServerAnsweredGiveBack(I64, Try(Book.Detail, BooksShow.GiveBackError)),
	]

	init : List(Book.Loan) -> Model
	init = |loans| { loans: loans, giving_back: Idle }

	view : Model -> Html(Msg)
	view = |model| {
		busy =
			match model.giving_back {
				GivingBack(_) => Bool.True
				_ => Bool.False
			}

		problem =
			match model.giving_back {
				Failed(text_) => text_
				_ => ""
			}

		empty_text = if model.loans.is_empty() "Nothing is on loan. Find a book in the catalog." else ""

		section(
			[class("loans")],
			[
				h1([], [text("On loan")]),
				# A plain link: the browser downloads the file, the app is not involved.
				p([class("download")], [a([href(Route.to_path(LoansCsv))], [text("Download as CSV")])]),
				p([class("status")], [text(empty_text)]),
				ul([class("books")], model.loans.map(|loan| view_loan(loan, busy))),
				p([class("error")], [text(problem)]),
			],
		)
	}
}

view_loan : Book.Loan, Bool -> Html(Index.Msg)
view_loan = |loan, busy|
	li(
		[class("book")],
		[
			a([href(Route.to_path(Book(loan.id)))], [text(loan.title)]),
			span([class("author")], [text(loan.author)]),
			span([class("borrower")], [text(loan.email)]),
			button([class("give-back"), disabled(busy), on_click(UserClickedGiveBack(loan.id))], [text("Give it back")]),
		],
	)
