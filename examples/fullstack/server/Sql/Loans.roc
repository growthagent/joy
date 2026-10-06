import pf.Sqlite
import /Db
import shared.Api
import shared.Book

## The statements about loans. A loan is keyed by its book in the schema
## (see Db.roc), so a book is out at most once.
Loans := [].{
	## Every book that is out, with who borrowed it, oldest loan first.
	all! : Sqlite.Db => Try(List(Book.Loan), [Server(Api.Failure)])
	all! = |db| {
		rows : List({ id : I64, title : Str, author : Str, email : Str })
		rows = Sqlite.query_many!({
			db,
			query:
			\\select books.id, books.title, books.author, loans.email
			\\from loans join books on books.id = loans.book_id
			\\order by loans.borrowed_at, books.id
			,
			params: {},
			limits: Sqlite.default_query_limits,
		}) ? Db.server

		Ok(rows)
	}

	## Lend the book to `email`, unless it is already out. The insert
	## returns a row only when it stored one, which says which happened.
	borrow! : Sqlite.Db, { book_id : I64, email : Str, now : I64 } => Try({}, [AlreadyOnLoan, Server(Api.Failure)])
	borrow! = |db, loan| {
		stored : List({ book_id : I64 })
		stored = Sqlite.query_many!({
			db,
			query: "insert into loans (book_id, email, borrowed_at) values (:book_id, :email, :now) on conflict (book_id) do nothing returning book_id",
			params: loan,
			limits: Sqlite.default_query_limits,
		}) ? Db.server

		if stored.is_empty() Err(AlreadyOnLoan) else Ok({})
	}

	## Put the book back on the shelf. A book already there stays there.
	give_back! : Sqlite.Db, I64 => Try({}, [Server(Api.Failure)])
	give_back! = |db, book_id| {
		Sqlite.execute!({ db, query: "delete from loans where book_id = :book_id", params: { book_id: book_id } }) ? Db.server
		Ok({})
	}
}
