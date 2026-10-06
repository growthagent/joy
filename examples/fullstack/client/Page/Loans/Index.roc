import /ApiClient
import pf.Effect
import shared.Api
import shared.PageLoansIndex
import shared.PageBooksShow

## Giving books back from the loans page. A book leaves the list once the
## server has taken it back.
Index := [].{
	update : PageLoansIndex.Model, PageLoansIndex.Msg -> (PageLoansIndex.Model, List(Effect(PageLoansIndex.Msg)))
	update = |model, msg|
		match msg {
			UserClickedGiveBack(book_id) =>
				match model.giving_back {
					GivingBack(_) => (model, [])
					_ => (
						{ ..model, giving_back: GivingBack(book_id) },
						[ApiClient.send(PageBooksShow.give_back(book_id), {}, |answer| ServerAnsweredGiveBack(book_id, answer))],
					)
				}

			ServerAnsweredGiveBack(book_id, Ok(_)) =>
				({ loans: model.loans.keep_if(|loan| loan.id != book_id), giving_back: Idle }, [])

			# The book is gone from the catalog, so it is not on loan either.
			ServerAnsweredGiveBack(book_id, Err(BookMissing)) =>
				({ loans: model.loans.keep_if(|loan| loan.id != book_id), giving_back: Failed("That book is no longer in the catalog.") }, [])

			ServerAnsweredGiveBack(book_id, Err(Server(failure))) => (
				{ ..model, giving_back: Failed(Api.failure_text(failure)) },
				[ApiClient.log_problem("Giving back book ${book_id.to_str()} failed", failure)],
			)
		}
}
