import http.Response
import /Ctx
import /Partial/Layout
import /Responses
import /Sql/Loans as LoansSql

## The loans page's server half: every book that is out, at `/loans`, and the
## same list as a CSV file at `/loans.csv` (see shared/Page/Loans/Index.roc).
## Giving a book back goes to the book page's endpoint, in
## server/Page/Books/Show.roc.
Index := [].{
	page! : Ctx.Ctx => Try(Response, _)
	page! = |ctx| {
		loans = LoansSql.all!(ctx.db)?
		Ok(Responses.html(200, Layout.app_page({ page: Loans(loans) })))
	}

	## The loans as a CSV file, one row per book that is out. Not JSON and
	## not a page, so it is a plain `get!` route that answers with a file:
	## no endpoint type, no client code, just a link on the loans page.
	csv! : Ctx.Ctx => Try(Response, _)
	csv! = |ctx| {
		loans = LoansSql.all!(ctx.db)?
		rows = loans.map(|loan| csv_row([loan.title, loan.author, loan.email]))
		Ok(Responses.download("loans.csv", "text/csv; charset=utf-8", Str.join_with([csv_row(["title", "author", "email"])].concat(rows), "\r\n").concat("\r\n")))
	}
}

csv_row : List(Str) -> Str
csv_row = |fields| Str.join_with(fields.map(csv_field), ",")

## One field of a CSV row (RFC 4180): quoted when it holds a comma, a quote
## or a line break, with its quotes doubled. A field that a spreadsheet would
## run as a formula (it starts with =, +, - or @) gets a leading apostrophe
## first, because anyone can type a title or an email here and someone else
## opens the file.
csv_field : Str -> Str
csv_field = |raw| {
	field =
		if raw.starts_with("=") or raw.starts_with("+") or raw.starts_with("-") or raw.starts_with("@") {
			"'${raw}"
		} else {
			raw
		}
	if field.contains(",") or field.contains("\"") or field.contains("\n") or field.contains("\r") {
		"\"${field.replace_each("\"", "\"\"")}\""
	} else {
		field
	}
}

expect csv_field("Emma") == "Emma"
expect csv_field("Austen, Jane") == "\"Austen, Jane\""
expect csv_field("The \"Lady\"") == "\"The \"\"Lady\"\"\""
expect csv_field("two\nlines") == "\"two\nlines\""
expect csv_field("=HYPERLINK(\"x\")") == "\"'=HYPERLINK(\"\"x\"\")\""
expect csv_field("@sum") == "'@sum"
expect csv_row(["a", "b,c"]) == "a,\"b,c\""
