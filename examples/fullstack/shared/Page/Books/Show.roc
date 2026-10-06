import /Api
import /Book
import /Route
import html.Html exposing [button, div, form, h1, input, label, p, section, text]
import html.Attribute exposing [autocomplete, class, disabled, for_, id, method, name, novalidate, on_click, on_input, on_submit, type, value]

## A book's page at `/books/7`: what it is, whether it is on the shelf, and
## the one thing to do about that. Borrowing asks for an email, so the
## library knows who has the book, and anyone can give a book back.
Show := [].{
	Model : { book : Book.Detail, email : Str, saving : Saving }

	## A borrow or a give-back on its way to the server. The page shows the
	## book as stored until the answer comes back with the new state.
	Saving : [Idle, Saving, Failed(Str)]

	Msg : [
		UserTypedEmail(Str),
		UserSubmittedBorrow,
		UserClickedGiveBack,
		ServerAnsweredBorrow(Try(Book.Detail, BorrowError)),
		ServerAnsweredGiveBack(Try(Book.Detail, GiveBackError)),
	]

	init : Book.Detail -> Model
	init = |book| { book: book, email: "", saving: Idle }

	## Why borrowing can fail: the book is gone, someone has it, the email
	## is not one (in the words `Book.check_borrower` uses), or `Server`.
	BorrowError : [BookMissing, AlreadyOnLoan, BadEmail(Str), Server(Api.Failure)]

	borrow : I64 -> Api.Endpoint(Book.Borrower, Book.Detail, BorrowError)
	borrow = |book_id|
		Api.post(
			Route.to_path(ApiLoan(book_id)),
			|error|
				match error {
					BookMissing => 404
					AlreadyOnLoan => 409
					BadEmail(_) => 422
					Server(failure) => Api.failure_status(failure)
				},
		)

	## Giving back only fails when the book is gone. Giving back a book
	## that is on the shelf leaves it there.
	GiveBackError : [BookMissing, Server(Api.Failure)]

	give_back : I64 -> Api.Endpoint({}, Book.Detail, GiveBackError)
	give_back = |book_id|
		Api.delete(
			Route.to_path(ApiLoan(book_id)),
			|error|
				match error {
					BookMissing => 404
					Server(failure) => Api.failure_status(failure)
				},
		)

	view : Model -> Html(Msg)
	view = |model| {
		book = model.book
		busy = model.saving == Saving

		action =
			match book.availability {
				OnShelf =>
					form(
						# POST, so a submit before the client has loaded never
						# puts the email in a URL (it gets a 405 instead).
						# `novalidate`, so the browser's own email check does not
						# stop the submit before Book.check_borrower can word the
						# problem the way the server would.
						[class("form borrow"), method("post"), novalidate(Bool.True), on_submit(UserSubmittedBorrow)],
						[
							label([for_("borrow-email")], [text("Your email")]),
							input([
								id("borrow-email"),
								name("email"),
								type("email"),
								autocomplete("email"),
								value(model.email),
								on_input(|typed| UserTypedEmail(typed)),
							]),
							button([type("submit"), disabled(busy)], [text(if busy "Borrowing..." else "Borrow")]),
						],
					)

				OnLoan =>
					button([class("give-back"), disabled(busy), on_click(UserClickedGiveBack)], [text("Give it back")])
			}

		problem =
			match model.saving {
				Failed(text_) => text_
				_ => ""
			}

		section(
			[class("book-page")],
			[
				h1([], [text(book.title)]),
				p([class("byline")], [text("${book.author}, ${book.year.to_str()}")]),
				p([class("shelf")], [text(shelf_text(book.availability))]),
				div([class("actions")], [action]),
				p([class("error")], [text(problem)]),
			],
		)
	}
}

shelf_text : Book.Availability -> Str
shelf_text = |availability|
	match availability {
		OnShelf => "On the shelf."
		OnLoan => "On loan."
	}
