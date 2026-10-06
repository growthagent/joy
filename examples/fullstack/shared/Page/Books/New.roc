import /Api
import /Book
import /Route
import html.Html exposing [button, form, h1, input, label, p, section, text]
import html.Attribute exposing [class, disabled, for_, id, inputmode, name, on_input, on_submit, type, value]

## Adding a book at `/books/new`. Anyone may, since the app has no sign-in:
## a real app puts this page behind one. The form is checked with
## `Book.check` before it is sent and again by the server, so both say the
## same thing about a mistake. A stored book opens its own page.
New := [].{
	Model : { title : Str, author : Str, year : Str, status : Status }

	Status : [Editing, Saving, Failed(Str)]

	Msg : [
		UserTypedTitle(Str),
		UserTypedAuthor(Str),
		UserTypedYear(Str),
		UserSubmitted,
		ServerAnsweredAdd(Try(Book.Detail, AddError)),
	]

	init : Model
	init = { title: "", author: "", year: "", status: Editing }

	## Why adding can fail: the book breaks a rule of `Book.check` (in its
	## words), or `Server`.
	AddError : [Invalid(Str), Server(Api.Failure)]

	add_book : Api.Endpoint(Book.New, Book.Detail, AddError)
	add_book = Api.created(
		Route.to_path(ApiBooks),
		|error|
			match error {
				Invalid(_) => 422
				Server(failure) => Api.failure_status(failure)
			},
	)

	## The book the form describes, or the first thing wrong with it, in the
	## order the form asks: title, author, year.
	to_book : Model -> Try(Book.New, Str)
	to_book = |model|
		match I64.from_str(model.year.trim()) {
			Ok(year) => Book.check({ title: model.title, author: model.author, year: year })
			Err(_) =>
				# The year is not a number, but a missing title or author
				# comes first. Any valid year lets Book.check speak to those.
				match Book.check({ title: model.title, author: model.author, year: 2000 }) {
					Err(problem) => Err(problem)
					Ok(_) => Err("The year must be a number, like 1847.")
				}
		}

	view : Model -> Html(Msg)
	view = |model| {
		saving = model.status == Saving

		problem =
			match model.status {
				Failed(text_) => text_
				_ => ""
			}

		section(
			[class("new-book")],
			[
				h1([], [text("Add a book")]),
				form(
					[class("form"), on_submit(UserSubmitted)],
					[
						label([for_("title")], [text("Title")]),
						input([id("title"), name("title"), value(model.title), on_input(|typed| UserTypedTitle(typed))]),
						label([for_("author")], [text("Author")]),
						input([id("author"), name("author"), value(model.author), on_input(|typed| UserTypedAuthor(typed))]),
						label([for_("year")], [text("Year")]),
						input([id("year"), name("year"), inputmode("numeric"), value(model.year), on_input(|typed| UserTypedYear(typed))]),
						button([type("submit"), disabled(saving)], [text(if saving "Adding..." else "Add the book")]),
						p([class("error")], [text(problem)]),
					],
				),
			],
		)
	}
}

expect New.to_book({ ..New.init, title: "Emma", author: "Jane Austen", year: " 1815 " }) == Ok({ title: "Emma", author: "Jane Austen", year: 1815 })
expect New.to_book({ ..New.init, title: "Emma", author: "Jane Austen", year: "soon" }) == Err("The year must be a number, like 1847.")
expect New.to_book({ ..New.init, author: "Jane Austen", year: "1815" }) == Err("The title is missing.")
expect New.to_book(New.init) == Err("The title is missing.")
expect New.to_book({ ..New.init, title: "Emma" }) == Err("The author is missing.")
