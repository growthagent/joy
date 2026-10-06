import /ApiClient
import pf.DOM
import pf.Effect
import shared.Api
import shared.PageBooksNew
import shared.Route

## Adding a book. The form is checked here first, with the same
## `Book.check` the server runs, so a mistake shows without a round trip.
## A stored book opens its own page.
New := [].{
	update : PageBooksNew.Model, PageBooksNew.Msg -> (PageBooksNew.Model, List(Effect(PageBooksNew.Msg)))
	update = |model, msg|
		match msg {
			UserTypedTitle(title) => ({ ..model, title: title }, [])
			UserTypedAuthor(author) => ({ ..model, author: author }, [])
			UserTypedYear(year) => ({ ..model, year: year }, [])
			UserSubmitted =>
				if model.status == Saving {
					(model, [])
				} else {
					match PageBooksNew.to_book(model) {
						Err(problem) => ({ ..model, status: Failed(problem) }, [])
						Ok(book) => ({ ..model, status: Saving }, [ApiClient.send(PageBooksNew.add_book, book, |answer| ServerAnsweredAdd(answer))])
					}
				}

			ServerAnsweredAdd(Ok(book)) => (model, [DOM.navigate(Route.to_path(Book(book.id)))])
			# The server found what the form check did not: its words are
			# Book.check's, the same the form would have used.
			ServerAnsweredAdd(Err(Invalid(why))) => ({ ..model, status: Failed(why) }, [])

			ServerAnsweredAdd(Err(Server(failure))) => (
				{ ..model, status: Failed(Api.failure_text(failure)) },
				[ApiClient.log_problem("Adding a book failed", failure)],
			)
		}
}
