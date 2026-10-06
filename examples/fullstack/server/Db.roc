import pf.Sqlite
import shared.Api
import shared.Book

## The database's shape and its starting content: the schema, created on
## first start, and the seed books. The statements about each kind of row
## live under Sql/ (Sql/Books.roc, Sql/Loans.roc).
Db := [].{
	## A database error as the `Server` failure the endpoints know. The SQL
	## modules use it on every statement (`? Db.server`), so a handler can pass
	## their errors on with a plain `?`. SQLite has no "briefly out", so every
	## database error is a `Bug`.
	server : err -> [Server(Api.Failure)]
	server = |cause| Server(Bug(Str.inspect(cause)))

	ensure_schema! : Sqlite.Db => Try({}, _)
	ensure_schema! = |db| {
		statements = [
			\\create table if not exists books (
			\\    id integer primary key autoincrement,
			\\    title text not null,
			\\    author text not null,
			\\    year integer not null
			\\)
			,
			# A book is on loan at most once: the book is the key, so a second
			# borrow of the same book cannot be stored, however close two
			# requests arrive.
			\\create table if not exists loans (
			\\    book_id integer primary key references books (id),
			\\    email text not null,
			\\    borrowed_at integer not null
			\\)
			,
		]
		for statement in statements {
			Sqlite.execute!({ db, query: statement, params: {} }) ? |err| DbErr(err)
		}
		Ok({})
	}

	## Fill an empty catalog with the seed books, so a fresh database has
	## something to show. A catalog with any book in it is left alone.
	seed_books! : Sqlite.Db => Try({}, _)
	seed_books! = |db| {
		counted : { books : I64 }
		counted = Sqlite.query!({ db, query: "select count(*) as books from books", params: {}, limits: Sqlite.default_query_limits }) ? |err| DbErr(err)
		if counted.books == 0 {
			insert_seed_books!(db)
		} else {
			Ok({})
		}
	}

	## Put the books back as they were seeded, with nothing on loan: the
	## state every browser test starts from.
	reset_books! : Sqlite.Db => Try({}, _)
	reset_books! = |db| {
		statements = [
			"delete from loans",
			"delete from books",
			# So the seed books get ids 1, 2, 3, ... every time.
			"delete from sqlite_sequence where name = 'books'",
		]
		for statement in statements {
			Sqlite.execute!({ db, query: statement, params: {} }) ? |err| DbErr(err)
		}
		insert_seed_books!(db)
	}
}

insert_seed_books! : Sqlite.Db => Try({}, _)
insert_seed_books! = |db| {
	for book in seed_books {
		Sqlite.execute!({ db, query: "insert into books (title, author, year) values (:title, :author, :year)", params: book }) ? |err| DbErr(err)
	}
	Ok({})
}

seed_books : List(Book.New)
seed_books = [
	{ title: "Pride and Prejudice", author: "Jane Austen", year: 1813 },
	{ title: "Frankenstein", author: "Mary Shelley", year: 1818 },
	{ title: "Jane Eyre", author: "Charlotte Brontë", year: 1847 },
	{ title: "Wuthering Heights", author: "Emily Brontë", year: 1847 },
	{ title: "Moby-Dick", author: "Herman Melville", year: 1851 },
	{ title: "Great Expectations", author: "Charles Dickens", year: 1861 },
	{ title: "Middlemarch", author: "George Eliot", year: 1871 },
	{ title: "The Time Machine", author: "H. G. Wells", year: 1895 },
]

