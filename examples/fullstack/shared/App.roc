import Book
import /Page/Books/Index as PageBooksIndex
import /Page/Books/New as PageBooksNew
import /Page/Books/Show as PageBooksShow
import /Page/Loans/Index as PageLoansIndex
import /Partial/Menu as Menu
import html.Html exposing [div, main, p, text]
import html.Attribute exposing [class]

## The application core both sides import: the model of whichever page is
## showing, its messages, and the whole view, header included.
##
## The server renders a page with `view` and the client's first render
## claims that markup node for node instead of building it again
## (hydration). That only works when both sides produce the markup from the
## same code and the same data, so the data is one value, `Flags`: the
## server builds it, renders `view(init(flags))`, and puts the flags in the
## page as JSON, and the client boots with `init(flags)` from that JSON.
##
## Each page keeps its model, messages, endpoints and view in its own
## module under Page/, its update under client/Page/ and its handlers under
## server/Page/, at the same path each time. This module only puts the
## pages together.
App := [].{
	## One field today. Data every page shares (who is looking, once the
	## app has sign-in) goes next to `page`.
	Flags : { page : PageData }

	## What the server read for a page, before any client state exists.
	PageData : [
		Catalog({ query : Str, books : List(Book.Summary) }),
		Book(Book.Detail),
		Loans(List(Book.Loan)),
		NewBook,
	]

	Model : { page : Page }

	Page : [
		Catalog(PageBooksIndex.Model),
		Book(PageBooksShow.Model),
		Loans(PageLoansIndex.Model),
		NewBook(PageBooksNew.Model),
		## The client could not read the flags, so it has no page to show.
		Broken,
	]

	## Each page's messages, wrapped in its tag.
	Msg : [
		CatalogMsg(PageBooksIndex.Msg),
		BookMsg(PageBooksShow.Msg),
		LoansMsg(PageLoansIndex.Msg),
		NewBookMsg(PageBooksNew.Msg),
	]

	init : Flags -> Model
	init = |flags| {
		page =
			match flags.page {
				Catalog(data) => Catalog(PageBooksIndex.init(data))
				Book(book) => Book(PageBooksShow.init(book))
				Loans(loans) => Loans(PageLoansIndex.init(loans))
				NewBook => NewBook(PageBooksNew.init)
			}
		{ page: page }
	}

	encode_flags : Flags -> Str
	encode_flags = |flags| Json.to_str(flags)

	decode_flags : Str -> Try(Flags, [BadFlags(Str)])
	decode_flags = |json|
		match Json.parse(json) {
			Ok(flags) => Ok(flags)
			Err(problem) => Err(BadFlags(Str.inspect(problem)))
		}

	## The document's `<title>`.
	title : Model -> Str
	title = |model|
		match model.page {
			Catalog(_) => "Catalog"
			Book(page) => page.book.title
			Loans(_) => "On loan"
			NewBook(_) => "Add a book"
			Broken => "Something went wrong"
		}

	view : Model -> Html(Msg)
	view = |model|
		div(
			[class("app")],
			[
				Menu.view(section(model)),
				main([class("page")], [view_page(model)]),
			],
		)
}

view_page : App.Model -> Html(App.Msg)
view_page = |model|
	match model.page {
		Catalog(page) => Html.map(PageBooksIndex.view(page), |msg| CatalogMsg(msg))
		Book(page) => Html.map(PageBooksShow.view(page), |msg| BookMsg(msg))
		Loans(page) => Html.map(PageLoansIndex.view(page), |msg| LoansMsg(msg))
		NewBook(page) => Html.map(PageBooksNew.view(page), |msg| NewBookMsg(msg))
		Broken => p([class("error")], [text("This page could not start. Reload to try again.")])
	}

## Which menu entry the page belongs to. A book's page belongs to the
## catalog, where it was found.
section : App.Model -> Menu.Section
section = |model|
	match model.page {
		Catalog(_) | Book(_) => Catalog
		Loans(_) => Loans
		NewBook(_) => NewBook
		Broken => Nowhere
	}

expect {
	flags : App.Flags
	flags = { page: Book({ id: 3, title: "Emma", author: "Jane Austen", year: 1815, availability: OnLoan }) }
	App.decode_flags(App.encode_flags(flags)) == Ok(flags)
}

expect {
	flags : App.Flags
	flags = { page: Loans([{ id: 3, title: "Emma", author: "Jane Austen", email: "ben@example.com" }]) }
	App.decode_flags(App.encode_flags(flags)) == Ok(flags)
}

expect {
	flags : App.Flags
	flags = { page: NewBook }
	App.decode_flags(App.encode_flags(flags)) == Ok(flags)
}

expect App.decode_flags("{\"page\":\"Nowhere\"}").is_err()
