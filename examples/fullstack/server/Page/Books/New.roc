import http.Response
import /Ctx
import /Partial/Layout
import /Responses
import /Sql/Books as BooksSql
import shared.Book
import shared.PageBooksNew

## The server half of adding a book: the form at `/books/new`, and storing
## what it sends (see shared/Page/Books/New.roc).
New := [].{
	page! : () => Try(Response, _)
	page! = ||
		Ok(Responses.html(200, Layout.app_page({ page: NewBook })))

	## Store the book, checked again with the rules the form used.
	add! : Ctx.Ctx, Book.New => Try(Book.Detail, PageBooksNew.AddError)
	add! = |ctx, submitted| {
		book = Book.check(submitted) ? |why| Invalid(why)
		book_id = BooksSql.add!(ctx.db, book)?
		# BookMissing is not one of this endpoint's errors, so the compiler
		# asks what it means here: a book stored a moment ago that cannot be
		# found is a bug.
		match BooksSql.find!(ctx.db, book_id) {
			Ok(detail) => Ok(detail)
			Err(BookMissing) => Err(Server(Bug("book ${book_id.to_str()} was stored but cannot be read back")))
			Err(Server(failure)) => Err(Server(failure))
		}
	}
}
