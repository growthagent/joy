import http.Response
import pf.UnixTime
import /Ctx
import /Partial/Layout
import /Responses
import /Sql/Books as BooksSql
import /Sql/Loans as LoansSql
import shared.Book
import shared.PageBooksShow

## A book page's server half: the page at `/books/7`, and lending the book
## and taking it back (see shared/Page/Books/Show.roc). The loans page gives
## books back through the same endpoint.
Show := [].{
	page! : Ctx.Ctx, I64 => Try(Response, _)
	page! = |ctx, book_id| {
		book = BooksSql.find!(ctx.db, book_id)?
		Ok(Responses.html(200, Layout.app_page({ page: Book(book) })))
	}

	## Lend the book to the email in the request. The SQL modules already
	## speak the endpoint's errors (BookMissing, AlreadyOnLoan, Server), so
	## each step passes its error on with a plain `?`.
	borrow! : Ctx.Ctx, I64, Book.Borrower => Try(Book.Detail, PageBooksShow.BorrowError)
	borrow! = |ctx, book_id, submitted| {
		borrower = Book.check_borrower(submitted) ? |why| BadEmail(why)
		_ = BooksSql.find!(ctx.db, book_id)?
		now = UnixTime.now!().seconds_since_epoch()
		LoansSql.borrow!(ctx.db, { book_id, email: borrower.email, now })?
		BooksSql.find!(ctx.db, book_id)
	}

	## Put the book back on the shelf. Giving back a book that is on the
	## shelf leaves it there.
	give_back! : Ctx.Ctx, I64 => Try(Book.Detail, PageBooksShow.GiveBackError)
	give_back! = |ctx, book_id| {
		_ = BooksSql.find!(ctx.db, book_id)?
		LoansSql.give_back!(ctx.db, book_id)?
		BooksSql.find!(ctx.db, book_id)
	}
}
