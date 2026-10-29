import html.Html exposing [code, h1, h2, p, text]
import html.Attribute exposing [class]
import /Doc

## The topic "Typed endpoints".
Endpoints := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Growing an app")]),
		h1([], [text("Typed endpoints")]),
		p(
			[class("lead")],
			[
				text("A JSON endpoint is defined once, in the page's shared module, with its request, its answer and its errors as types. The server and the client are both held to it."),
			],
		),
		Doc.code(
			Roc,
			"shared/Page/Books/Show.roc",
			\\BorrowError : [BookMissing, AlreadyOnLoan, BadEmail(Str), Server(Api.Failure)]
			\\
			\\borrow : I64 -> Api.Endpoint(Book.Borrower, Book.Detail, BorrowError)
			\\borrow = |book_id|
			\\    Api.post(
			\\        Route.to_path(ApiLoan(book_id)),
			\\        |error|
			\\            match error {
			\\                BookMissing => 404
			\\                AlreadyOnLoan => 409
			\\                BadEmail(_) => 422
			\\                Server(failure) => Api.failure_status(failure)
			\\            },
			\\    )
		),
		h2([], [text("The server's handler")]),
		p(
			[],
			[
				text("A handler takes the decoded request and returns the answer or one of the endpoint's errors. It reads no body, sets no status and builds no JSON. "),
				code([], [text("ApiServer.on")]),
				text(" does all of that."),
			],
		),
		Doc.code(
			Roc,
			"server/Page/Books/Show.roc",
			\\borrow! : Ctx.Ctx, I64, Book.Borrower => Try(Book.Detail, PageBooksShow.BorrowError)
			\\borrow! = |ctx, book_id, submitted| {
			\\    borrower = Book.check_borrower(submitted) ? |why| BadEmail(why)
			\\    _ = BooksSql.find!(ctx.db, book_id)?
			\\    now = UnixTime.now!().seconds_since_epoch()
			\\    LoansSql.borrow!(ctx.db, { book_id, email: borrower.email, now })?
			\\    BooksSql.find!(ctx.db, book_id)
			\\}
		),
		h2([], [text("The client's side")]),
		p(
			[],
			[
				text("The client sends with the endpoint, and the answer arrives as a message carrying a "),
				code([], [text("Try")]),
				text(", which the page matches like any other value:"),
			],
		),
		Doc.code(
			Roc,
			"client/Page/Books/Show.roc",
			\\UserSubmittedBorrow =>
			\\    ({ ..model, saving: Saving }, [ApiClient.send(PageBooksShow.borrow(model.book.id), borrower, |answer| ServerAnsweredBorrow(answer))])
			\\
			\\ServerAnsweredBorrow(Ok(book)) => stored(book)
			\\ServerAnsweredBorrow(Err(AlreadyOnLoan)) => (failed(model, "This book is already on loan."), [])
			\\ServerAnsweredBorrow(Err(BadEmail(why))) => (failed(model, why), [])
			\\ServerAnsweredBorrow(Err(BookMissing)) => (failed(model, "This book is no longer in the catalog."), [])
			\\ServerAnsweredBorrow(Err(Server(failure))) => (failed(model, Api.failure_text(failure)), [])
		),
		p(
			[],
			[
				text("Rename a field on one side and the other stops compiling. Add an error to "),
				code([], [text("BorrowError")]),
				text(" and the page does not compile until it has words for it. A handler cannot return an error the endpoint does not list."),
			],
		),
		h2([], [text("Server(Api.Failure)")]),
		p(
			[],
			[
				text("Every endpoint's errors end with "),
				code([], [text("Server(Api.Failure)")]),
				text(": anything that went wrong that is not one of its own errors. It covers no answer at all, a timeout, an answer the page cannot read, and on the server side a service that is briefly out, a failing upstream and plain bugs. The page usually has one set of words for all of them and matches a single case when it has better ones."),
			],
		),
		p(
			[],
			[
				text("A "),
				code([], [text("Server")]),
				text(" failure loses its details on the way out. The browser gets a status and a short error, never the database's message."),
			],
		),
	]
}
