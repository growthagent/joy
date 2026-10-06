import /Api
import /Book
import /Route
import html.Html exposing [a, form, h1, input, label, li, p, section, span, text, ul]
import html.Attribute exposing [action, autocomplete, class, class_list, for_, href, id, method, name, on_input, on_submit, role, type, value]

## The catalog at `/`: every book, or the ones matching a search. Typing
## searches as you go (client/Page/Books/Index.roc) and keeps the query in
## the URL, so a reload or a shared link shows the same books. The form is
## a real GET form too, so the search works before the client has loaded.
Index := [].{
	Model : {
		## What is in the search box.
		query : Str,
		## The books for the last search that came back.
		books : List(Book.Summary),
		search : Search,
	}

	## Where the search for `query` is. While one runs, `books` still shows
	## the previous answer.
	Search : [Done, Searching, Failed(Str)]

	Msg : [
		UserTypedQuery(Str),
		UserSubmittedSearch,
		## Typing paused: time to search for what the box says now.
		UserPausedTyping,
		## The answer to the search for this query.
		ServerAnsweredSearch(Str, Try(List(Book.Summary), SearchError)),
	]

	init : { query : Str, books : List(Book.Summary) } -> Model
	init = |data| { query: data.query, books: data.books, search: Done }

	## A search can only fail for reasons outside the catalog.
	SearchError : [Server(Api.Failure)]

	search_books : Str -> Api.Endpoint({}, List(Book.Summary), SearchError)
	search_books = |query|
		Api.get(
			Route.to_path(ApiSearch({ query: query })),
			|error|
				match error {
					Server(failure) => Api.failure_status(failure)
				},
		)

	view : Model -> Html(Msg)
	view = |model| {
		failed =
			match model.search {
				Failed(_) => Bool.True
				_ => Bool.False
			}

		section(
			[class("catalog")],
			[
				h1([], [text("Catalog")]),
				form(
					[class("search"), action("/"), method("get"), role("search"), on_submit(UserSubmittedSearch)],
					[
						label([for_("search-query")], [text("Search by title or author")]),
						input([
							id("search-query"),
							type("search"),
							name("q"),
							autocomplete("off"),
							value(model.query),
							on_input(|typed| UserTypedQuery(typed)),
						]),
					],
				),
				# Always rendered, so every render has the same structure.
				p([class_list([("status", Bool.True), ("error", failed)])], [text(status_text(model))]),
				ul([class("books")], model.books.map(view_book)),
			],
		)
	}
}

status_text : Index.Model -> Str
status_text = |model|
	match model.search {
		Searching => "Searching..."
		Failed(problem) => problem
		Done =>
			if !model.books.is_empty() {
				""
			} else if model.query.is_empty() {
				"The catalog is empty."
			} else {
				"No books match \"${model.query}\"."
			}
	}

view_book : Book.Summary -> Html(Index.Msg)
view_book = |book| {
	on_loan = book.availability == OnLoan
	li(
		[class("book")],
		[
			a([href(Route.to_path(Book(book.id)))], [text(book.title)]),
			span([class("author")], [text(book.author)]),
			span(
				[class_list([("badge", Bool.True), ("on-loan", on_loan)])],
				[text(if on_loan "On loan" else "On the shelf")],
			),
		],
	)
}
