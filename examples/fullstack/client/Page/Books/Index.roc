import /ApiClient
import pf.DOM
import pf.Effect
import pf.Time
import shared.Api
import shared.PageBooksIndex
import shared.Route

## Search as you type: every keystroke re-arms one debounce timer, and the
## search runs once typing pauses. The URL follows the query (replaced, not
## pushed, so Back does not step through every keystroke).
Index := [].{
	update : PageBooksIndex.Model, PageBooksIndex.Msg -> (PageBooksIndex.Model, List(Effect(PageBooksIndex.Msg)))
	update = |model, msg|
		match msg {
			UserTypedQuery(query) => ({ ..model, query: query }, [Time.debounce(debounce_key, 250, |_| UserPausedTyping)])

			# The user pressed Enter to immediately submit this query, so
			# we cancel the debounce for "user is typing" so that we don't
			# submit the query again.
			UserSubmittedSearch => search(model, [Time.cancel(debounce_key)])

			UserPausedTyping => search(model, [])

			ServerAnsweredSearch(query, answer) =>
				if query != model.query {
					# The answer we got isn't for our current query, so we ignore it.
					(model, [])
				} else {
					match answer {
						Ok(books) => ({ ..model, books: books, search: Done }, [])
						Err(Server(failure)) => (
							{ ..model, search: Failed(Api.failure_text(failure)) },
							[ApiClient.log_problem("Searching for \"${query}\" failed", failure)],
						)
					}
				}
		}
}

debounce_key : Str
debounce_key = "catalog-search"

search : PageBooksIndex.Model, List(Effect(PageBooksIndex.Msg)) -> (PageBooksIndex.Model, List(Effect(PageBooksIndex.Msg)))
search = |model, effects| {
	query = model.query
	(
		{ ..model, search: Searching },
		effects.concat([
			DOM.replace_url(Route.to_path(Catalog({ query: query }))),
			ApiClient.get(PageBooksIndex.search_books(query), |answer| ServerAnsweredSearch(query, answer)),
		]),
	)
}
