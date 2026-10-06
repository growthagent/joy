import /ApiClient
import pf.Effect
import shared.Api
import shared.Book
import shared.PageBooksShow

## Borrowing and giving back. The email is checked here first, with the same
## `Book.check_borrower` the server runs, so a mistake shows without a round
## trip. The page shows the book as stored and only changes when the server
## answers with the book's new state, so it never shows a loan that did not
## happen.
##
## Each of the endpoint's errors gets its own words here. Only `Server(...)`,
## the failures that are not about books, falls back to `Api.failure_text`.
Show := [].{
	update : PageBooksShow.Model, PageBooksShow.Msg -> (PageBooksShow.Model, List(Effect(PageBooksShow.Msg)))
	update = |model, msg|
		match msg {
			UserTypedEmail(email) => ({ ..model, email: email }, [])

			UserSubmittedBorrow =>
				if model.saving == Saving {
					(model, [])
				} else {
					match Book.check_borrower({ email: model.email }) {
						Err(problem) => ({ ..model, saving: Failed(problem) }, [])
						Ok(borrower) => (
							{ ..model, saving: Saving },
							[ApiClient.send(PageBooksShow.borrow(model.book.id), borrower, |answer| ServerAnsweredBorrow(answer))],
						)
					}
				}

			# One request at a time: the button is disabled while one is out,
			# and this catches a click that gets past it.
			UserClickedGiveBack =>
				if model.saving == Saving {
					(model, [])
				} else {
					(
						{ ..model, saving: Saving },
						[ApiClient.send(PageBooksShow.give_back(model.book.id), {}, |answer| ServerAnsweredGiveBack(answer))],
					)
				}

			ServerAnsweredBorrow(Ok(book)) => stored(book)
			# The 409 is the server's word that the book is out, so the page
			# shows it out instead of a form that can only fail again.
			ServerAnsweredBorrow(Err(AlreadyOnLoan)) => (failed({ ..model, book: { ..model.book, availability: OnLoan } }, "This book is already on loan."), [])
			ServerAnsweredBorrow(Err(BadEmail(why))) => (failed(model, why), [])
			ServerAnsweredBorrow(Err(BookMissing)) => (failed(model, missing), [])
			ServerAnsweredBorrow(Err(Server(failure))) => server_failed(model, "Borrowing", failure)

			ServerAnsweredGiveBack(Ok(book)) => stored(book)
			ServerAnsweredGiveBack(Err(BookMissing)) => (failed(model, missing), [])
			ServerAnsweredGiveBack(Err(Server(failure))) => server_failed(model, "Giving back", failure)
		}
}

## The server stored the change and answered with the book as it is now.
stored : Book.Detail -> (PageBooksShow.Model, List(Effect(PageBooksShow.Msg)))
stored = |book| ({ book: book, email: "", saving: Idle }, [])

failed : PageBooksShow.Model, Str -> PageBooksShow.Model
failed = |model, words| { ..model, saving: Failed(words) }

missing : Str
missing = "This book is no longer in the catalog."

server_failed : PageBooksShow.Model, Str, Api.Failure -> (PageBooksShow.Model, List(Effect(PageBooksShow.Msg)))
server_failed = |model, what, failure| (
	failed(model, Api.failure_text(failure)),
	[ApiClient.log_problem("${what} book ${model.book.id.to_str()} failed", failure)],
)
