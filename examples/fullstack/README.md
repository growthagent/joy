# Joy fullstack example

Shelf, a small lending library, as a full-stack [Joy](https://github.com/niclas-ahden/joy) app in [Roc](https://www.roc-lang.org): a wasm client, a server on [basic-webserver](https://github.com/niclas-ahden/basic-webserver) with a SQLite database, and a shared package with every page's model, view and endpoints. Anyone can search the catalog, borrow a book with their email, give it back, see what is on loan and add new books.

`examples/todomvc-fullstack` shows the core idea on one page. This example is the shape of an app with several pages: one type for every URL, a routing table that says who may use each route, typed JSON endpoints that both sides share, a menu between the pages, and one HTML shell for every page.

The app has no sign-in. Anyone may do anything, and the pages that a real app would put behind a sign-in say so (adding books, and the loans page, which shows borrowers' emails). See "What it leaves out" below.

## Run it

```sh
$ ./dev.roc
```

The app is now at [`http://localhost:8000`](http://localhost:8000) (set `PORT` to change that, and `HOST` to listen on another address than 127.0.0.1, such as 0.0.0.0 in a container). `./dev.roc` builds the client, rebuilds it on every save, and runs the server with hot reload, like the TodoMVC fullstack example.

The database lands in `./library.db` (set `DB_PATH` to change that). The schema is created on first start, and an empty catalog gets eight seed books.

This directory is developed inside the Joy repo, and the client's header points at the checkout's platform. Build Joy's wasm host once with `./build.roc -- --opt=speed` at the repo root, and use the compiler that `nix develop` hands you (the one `flake.nix` pins). Without Nix, put Roc on your PATH (we recommend [`roc nightly-2026-10-06-c34079d`](https://github.com/roc-lang/nightlies/releases/tag/nightly-2026-10-06-c34079d)).

## How it is put together

### Where a page lives

A page has three halves, one per directory, at the same path in each:

```
shared/Page/Books/Show.roc    model, messages, endpoints, view   (both sides compile it)
client/Page/Books/Show.roc    update                             (only the browser)
server/Page/Books/Show.roc    page!, borrow!, give_back!         (only the server)
```

Pages are named by resource and action, like Rails: `Page/Books/Index.roc` is the catalog, `Show.roc` a book's page, `New.roc` the form that adds one, and `Page/Loans/Index.roc` the list of loans. Knowing one half tells you where the other two are.

The directories also keep the sides apart. `shared/` cannot import Joy's platform or basic-webserver, so a view cannot do I/O and both sides can render it. `client/` cannot reach the database and `server/` cannot use browser effects. A wrong import does not compile.

A module in a directory is imported by its path, from the package root: `import /Page/Books/Show as PageBooksShow`. A bare `import Book` inside `Page/Books/` would look for `Page/Books/Book.roc`, so nested modules write `import /Book`. `shared/main.roc` gives each page the flat name the other packages use (`shared.PageBooksShow`).

Adding a page is a fixed list, and the compiler checks each step:

1. A tag in `Route.Route`, with its `parse` and `to_path` arms.
2. `shared/Page/<Resource>/<Action>.roc`, and its line in `shared/main.roc`.
3. `client/Page/<Resource>/<Action>.roc`, and its arm in `client/main.roc`'s `update`.
4. `server/Page/<Resource>/<Action>.roc`, and its row in the routing table.
5. Its tags in `App.PageData`, `App.Page` and `App.Msg`, and an entry in the menu if it needs one.

### Partials

A partial is a piece of view that several pages use, under `Partial/`. `shared/Partial/Menu.roc` is the header with the menu: the app's pages show it through `App.view`, and the server's own 404 and 500 pages through `server/Partial/Layout.roc`, so the whole site has one header. A partial is built only from what it is given (here, which entry is current), so it works for any page.

### One type for every URL

`shared/Route.roc` has every URL the app answers as one tag union, `Route.Route`, with `parse` (a request target to a route) and `to_path` (a route to its URL). Every link and every API endpoint is built with `to_path`, so each URL is spelled in exactly one place, and the expects at the bottom of the module hold `parse` to be its inverse.

### A routing table

`route!` in `server/main.roc` is the routing table: one row per route, saying how it is answered and by which page's handler. The match is exhaustive, so a new route does not compile until it has a row. A row answers in one of three ways (`server/Routing.roc`):

```roc
# get!: anything fetched with GET (HEAD too): a page, a redirect, a file
Catalog({ query }) => Routing.get!(req, || ServerBooksIndex.page!(ctx, query))
LoansCsv => Routing.get!(req, || ServerLoansIndex.csv!(ctx))

# api!: JSON endpoints, each with its handler. The endpoints decide the methods.
ApiLoan(book_id) =>
	Routing.api!(req, [
		ApiServer.on(PageBooksShow.borrow(book_id), |borrower| ServerBooksShow.borrow!(ctx, book_id, borrower)),
		ApiServer.on(PageBooksShow.give_back(book_id), |{}| ServerBooksShow.give_back!(ctx, book_id)),
	])

# raw!: a route that reads the request itself, like an upload, and names its methods
```

Another method gets a 405 with an `Allow` header, and HEAD counts as GET (the platform drops the body and keeps the length). `server/main.roc` holds nothing else but the configuration.

There is no sign-in, so no row says who may use it. An app with sign-in gives each of the three an access level, written as a tag around the handler, like `Routing.get!(req, ctx, AnyAdmin(|user| ...))`: no row can leave it out, and the handler gets a user exactly when the level means there is one.

### Pages, hydration and UI state

`shared/App.roc` puts the pages together with the menu that every page shares.

The server renders a page from `App.Flags`, the data it read for the page, and puts the flags in the page as JSON. The client boots from those flags, and both sides build the model with `App.init`, so the client's first render produces the same markup the server sent and claims it instead of building it again. The browser tests check that every page is claimed cleanly.

The menu's entries are real links, so moving between pages is a navigation: the server renders the next page and the client claims it. The entry for the page showing carries `aria-current="page"`, which the stylesheet marks.

Messages are facts in the past tense, named after who did what: `UserTypedQuery`, `UserPausedTyping`, `ServerAnsweredSearch`. The update decides what a fact means.

UI state is tags, not strings or loose booleans. The catalog's search is `[Done, Searching, Failed(Str)]`, a book page's loan request is `[Idle, Saving, Failed(Str)]`, and the view matches on them, so a state the page has no view for does not compile.

### Typed endpoints

`shared/Api.roc` defines `Api.Endpoint(request, answer, error)`: a method and a path, with the request, the answer and the errors as types. Each page defines its endpoints once, built from routes, with the status each error goes out with:

```roc
BorrowError : [BookMissing, AlreadyOnLoan, BadEmail(Str), Server(Api.Failure)]

borrow : I64 -> Api.Endpoint(Book.Borrower, Book.Detail, BorrowError)
borrow = |book_id|
	Api.post(
		Route.to_path(ApiLoan(book_id)),
		|error|
			match error {
				BookMissing => 404
				AlreadyOnLoan => 409
				BadEmail(_) => 422
				Server(failure) => Api.failure_status(failure)
			},
	)
```

The server answers it with a handler that takes the request and returns the answer or one of those errors, and nothing else: it reads no body, sets no status and builds no JSON (`ApiServer.on` does). The SQL modules already speak the endpoints' errors, so a handler passes theirs on with a plain `?`:

```roc
borrow! : Ctx.Ctx, I64, Book.Borrower => Try(Book.Detail, PageBooksShow.BorrowError)
borrow! = |ctx, book_id, submitted| {
	borrower = Book.check_borrower(submitted) ? |why| BadEmail(why)
	_ = BooksSql.find!(ctx.db, book_id)?
	now = UnixTime.now!().seconds_since_epoch()
	LoansSql.borrow!(ctx.db, { book_id, email: borrower.email, now })?
	BooksSql.find!(ctx.db, book_id)
}
```

The client sends with the endpoint and gets a `Try(Book.Detail, BorrowError)`, which the page matches like any other value:

```roc
ServerAnsweredBorrow(Ok(book)) => stored(book)
ServerAnsweredBorrow(Err(AlreadyOnLoan)) => (failed(model, "This book is already on loan."), [])
ServerAnsweredBorrow(Err(BadEmail(why))) => (failed(model, why), [])
ServerAnsweredBorrow(Err(BookMissing)) => (failed(model, missing), [])
ServerAnsweredBorrow(Err(Server(failure))) => server_failed(model, "Borrowing", failure)
```

The compiler holds all three to the endpoint. A field renamed on one side does not compile on the other. A handler that returns an error the endpoint does not list does not compile, nor does one that lets an unconverted error through `?`, nor a handler wired to the wrong endpoint. A new error added to `BorrowError` does not compile until the page has words for it.

### Endpoint errors and `Server`

Every endpoint's errors end with `Server(Api.Failure)`: whatever went wrong that is not one of its own errors, on the server or on the way to it. The page usually has one set of words for all of it (`Api.failure_text`) and matches a single case when it has better ones:

| `Api.Failure` | Means | Comes from |
|---|---|---|
| `NoAnswer` | no answer at all: offline, DNS, a refused connection | the client |
| `Timeout` | no answer in time | the client |
| `Unexpected(status, body)` | a status the endpoint never answers with: a proxy's error page, a route that no longer exists | the client |
| `Incompatible(why)` | an answer the page cannot read, usually because the page and the server are different versions: a reload fixes it | the client |
| `Unavailable(cause)` | something the server needs is briefly out (503) | the server |
| `Upstream(service, cause)` | a service the server depends on failed (502) | the server |
| `Bug(cause)` | anything the server did not plan for (500) | the server |

A `Server` failure is logged with the request it came from, and loses its cause on the way out: the browser gets `{"Server":{"Bug":""}}` with a 500, never the database's error message. An endpoint's own errors go out as themselves, `"AlreadyOnLoan"` with a 409 or `{"BadEmail":"Fill in your email."}` with a 422.

### Files and other answers that are not JSON

`/loans.csv` is the loans page's list as a CSV file. It is a plain `get!` row whose handler answers with `Responses.download`: no endpoint type and no client code, just a link on the loans page that the browser downloads. Its fields are quoted the way RFC 4180 says, and a field a spreadsheet would run as a formula (one starting with `=`, `+`, `-` or `@`) gets a leading apostrophe, because anyone can type a title or an email and someone else opens the file.

### One set of rules, checked twice

`Book.check` (a new book) and `Book.check_borrower` (the email a book is borrowed with) live in `shared/Book.roc`. The client runs them before it sends, so a mistake shows at once, and the server runs them again, because a request can come from anywhere. Both say the same words about the same mistake. The borrow form turns off the browser's own email check (`novalidate`), so those words are the only ones.

### Who has a book

Borrowing asks for an email, and the loan is stored with it. The loans page lists every book that is out with its borrower's email. A book's own page only says whether the book is out: `Book.Detail` has no field for the borrower, so neither the page nor its flags can carry the email.

### SQL

The statements about each kind of row are in `server/Sql/` (`Sql/Books.roc`, `Sql/Loans.roc`), and the schema and the seed books in `server/Db.roc`. Every value travels as a named parameter (`:title` with `{ title: ... }`), never spliced into the SQL. The one piece of SQL built from input is a search's LIKE pattern, and its wildcards are escaped first. Rules the database can enforce are in the schema: a loan is keyed by its book, so two people borrowing the same book at the same moment cannot both succeed, and the second gets a 409. The SQL modules answer in the endpoints' own errors: `BooksSql.find!` fails with `BookMissing`, `LoansSql.borrow!` with `AlreadyOnLoan`, and any database error becomes `Server(Bug(...))` through `Db.server`.

### JSON

All JSON goes through `Json.to_str` and `Json.parse` with a typed value on the other end: the flags, the API requests and answers, the error bodies. None of it is built from strings.

Every request with a body must be JSON. Another site can make a browser post a form here without asking, but not JSON. That matters once the app has sign-in, and costs nothing before.

### One layout, one font

`server/Partial/Layout.roc` writes the document around every HTML page, the server's own 404 and 500 pages included, with the same head and the same stylesheet. So every page has the same font: the system's own interface font, which needs no download and never flashes. A page of the app carries the client and its flags, and a message page carries no client at all.

### Failures

A JSON endpoint's errors, `Server` failures included, are answered by `ApiServer.on`. `Routing.finish!` handles the rest: a `get!` or `raw!` handler's failure, and a request `api!` could not read. A book that does not exist is the 404 page. A request that is not JSON (415), not the endpoint's shape (400) or too large (413) gets a status and words for whoever debugs the client. Anything else is logged with the request and the route and answered with a 500 page that gives nothing away. Logging writes to stderr, and an error tracker plugs in there.

### Assets

Everything in `client/www/` is served under `/assets/` by the platform itself, the stylesheet, the loader, and the wasm and runtime `build.roc` puts there, without entering Roc.

### Health checks

`/health/live` and `/health/ready` are for a container runtime or a load balancer. The platform answers both itself, so they answer even while every Roc handler is busy. `/health/live` answers 200 while the server runs. `/health/ready` answers 200 too, until a graceful stop begins and it turns to 503, so traffic moves to another instance before this one goes away.

## Test it

```sh
$ ./tests.roc
```

Runs the expects in `shared/` and `server/`, builds the client, and runs the tests in `e2e/` in parallel, each worker with its own server and its own scratch database, so `./library.db` is never touched. The seed books are put back before every test through `/test/reset`, a route that exists only when the server starts with `TEST_ROUTES=1`. Set `E2E_PORT` to move the workers' ports (default 8927 and up). This needs [`playwright`](https://playwright.dev) with a chromium installed (`nix develop` covers it).

* `routing_test.roc` checks the routing rules over plain HTTP: methods, 404s, health checks, which bodies the API takes, how each endpoint error goes out, adding books, borrowing and giving back, the CSV file, and that a book's page never names its borrower.
* `catalog_test.roc`, `borrow_test.roc` and `add_book_test.roc` walk through the app in a real browser, the menu included, and check that each page is claimed cleanly.
* `failure_test.roc` stages failed requests in the browser with roc-playwright's `with_routes!` (a busy server, a proxy's error page, an answer of the wrong shape, a dropped connection) and checks what the pages say.

## Where things live

```
shared/                     compiled into both sides
  Route.roc                 every URL: parse, to_path
  Api.roc                   typed endpoints, their errors, and Api.Failure
  Book.roc                  the book types both sides share, and the rules both check
  App.roc                   the flags, the model, the messages, the pages put together
  Page/Books/Index.roc      the catalog         ┐
  Page/Books/Show.roc       a book's page       │ model, messages, endpoints, view
  Page/Books/New.roc        adding a book       │
  Page/Loans/Index.roc      what is on loan     ┘
  Partial/Menu.roc          the header and menu every page shows
client/                     only the browser
  main.roc                  booting from the flags, handing each message to its page
  ApiClient.roc             sending to an endpoint
  Page/...                  each page's update, at the same paths as in shared/
  www/                      the loader, the stylesheet, the built wasm and runtime
server/                     only the server
  main.roc                  the configuration and the routing table
  Routing.roc               get!, api!, raw!: the ways a row answers, and finish!
  ApiServer.roc             on, serve!: answering JSON endpoints through their handlers
  Responses.roc             HTML, text and the 405
  Ctx.roc                   what every handler gets
  Page/...                  each page's handlers, at the same paths as in shared/
  Partial/Layout.roc        the document around every page
  Sql/Books.roc  Sql/Loans.roc   the statements about each kind of row
  Db.roc                    the schema and the seed books
e2e/                        the browser and HTTP tests, Browser.roc for their shared steps
tests.roc                   the test runner
dev.roc  build.roc  watch-client.roc  watch-server.roc   the dev scripts, Script.roc for their helpers
```

## What it leaves out

* There is no sign-in, so anyone may add books, borrow and give back any book, and see who has borrowed what. A real app puts adding books and the loans page behind a sign-in, and keeps borrowers' emails to the people who need them.
* An email is checked for its shape only. Nothing confirms that it belongs to the person who typed it.
* The schema is created on first start (`Db.ensure_schema!`), and there are no migrations. A `library.db` made by an older version of this example may not fit the schema: delete it and the next start makes a new one.
* A search answers with at most 100 books, without pagination.

## Things to try

* Add a page: follow the list under "Where a page lives", say an author page at `Page/Authors/Show.roc`, and let the compiler walk you through the rest.
* Show how long each book has been out: `loans.borrowed_at` is already stored, so it takes a field on `Book.Loan`, the query in `Sql/Loans.roc`, and the view in `shared/Page/Loans/Index.roc`.
* Make the email check stricter in `Book.check_borrower` and watch both the form and the API follow.
