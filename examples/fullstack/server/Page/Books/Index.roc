import http.Response
import /Ctx
import /Partial/Layout
import /Responses
import /Sql/Books as BooksSql
import shared.Book
import shared.PageBooksIndex

## The catalog's server half: the page at `/`, and the search the page runs
## as you type (see shared/Page/Books/Index.roc).
Index := [].{
	page! : Ctx.Ctx, Str => Try(Response, _)
	page! = |ctx, query| {
		books = BooksSql.search!(ctx.db, query)?
		Ok(Responses.html(200, Layout.app_page({ page: Catalog({ query, books }) })))
	}

	search! : Ctx.Ctx, Str => Try(List(Book.Summary), PageBooksIndex.SearchError)
	search! = |ctx, query| BooksSql.search!(ctx.db, query)
}
