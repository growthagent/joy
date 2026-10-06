import pf.Sqlite
import /Db
import shared.Api
import shared.Book

## The statements about books. Values always travel as named parameters
## (`:title`, `{ title: ... }`), never spliced into the SQL text, so no input
## can change what a statement does. The one piece of SQL built from input
## is a LIKE pattern, and its wildcards are escaped first (see
## `like_pattern`).
##
## SQLite has no booleans: whether a book is out comes back as 0 or 1 and is
## turned into a `Book.Availability` here, at the edge.
Books := [].{
	## Books whose title or author contains `query`, ignoring ASCII case. An
	## empty query matches every book.
	search! : Sqlite.Db, Str => Try(List(Book.Summary), [Server(Api.Failure)])
	search! = |db, query| {
		rows : List({ id : I64, title : Str, author : Str, on_loan : I64 })
		rows = Sqlite.query_many!({
			db,
			query:
			\\select books.id, books.title, books.author, loans.book_id is not null as on_loan
			\\from books left join loans on loans.book_id = books.id
			\\where books.title like :pattern escape '!' or books.author like :pattern escape '!'
			\\order by books.title collate nocase, books.id
			\\limit 100
			,
			params: { pattern: like_pattern(query.trim()) },
			limits: Sqlite.default_query_limits,
		}) ? Db.server

		Ok(rows.map(|row| { id: row.id, title: row.title, author: row.author, availability: availability(row.on_loan) }))
	}

	## The book and whether it is out. Who has it stays in the database.
	find! : Sqlite.Db, I64 => Try(Book.Detail, [BookMissing, Server(Api.Failure)])
	find! = |db, book_id| {
		rows : List({ id : I64, title : Str, author : Str, year : I64, on_loan : I64 })
		rows = Sqlite.query_many!({
			db,
			query:
			\\select books.id, books.title, books.author, books.year, loans.book_id is not null as on_loan
			\\from books left join loans on loans.book_id = books.id
			\\where books.id = :book_id
			,
			params: { book_id: book_id },
			limits: Sqlite.default_query_limits,
		}) ? Db.server

		match rows.first() {
			Ok(row) => Ok({ id: row.id, title: row.title, author: row.author, year: row.year, availability: availability(row.on_loan) })
			Err(_) => Err(BookMissing)
		}
	}

	## Store a book that passed `Book.check`, and give back its id.
	add! : Sqlite.Db, Book.New => Try(I64, [Server(Api.Failure)])
	add! = |db, book| {
		row : { id : I64 }
		row = Sqlite.query!({
			db,
			query: "insert into books (title, author, year) values (:title, :author, :year) returning id",
			params: book,
			limits: Sqlite.default_query_limits,
		}) ? Db.server
		Ok(row.id)
	}
}

availability : I64 -> Book.Availability
availability = |on_loan| if on_loan == 0 OnShelf else OnLoan

## A LIKE pattern that matches `text` anywhere. `%` and `_` in the text are
## escaped so they match themselves, with `!` as the escape character, as
## the `escape '!'` in the query says.
like_pattern : Str -> Str
like_pattern = |text| {
	escaped = text.replace_each("!", "!!").replace_each("%", "!%").replace_each("_", "!_")
	"%${escaped}%"
}

expect like_pattern("dune") == "%dune%"
expect like_pattern("100%_off!") == "%100!%!_off!!%"
expect availability(0) == OnShelf and availability(1) == OnLoan
