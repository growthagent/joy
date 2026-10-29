# The routing rules of server/main.roc, checked over plain HTTP: which
# methods a route takes, what the API accepts, how each endpoint's errors go
# out (a status and the error itself as JSON, like 409 and "AlreadyOnLoan"),
# and the CSV download. No browser: each request is made by hand and its answer
# checked as it comes off the wire, status, headers and body.
#
# Run via ./tests.roc, which starts a server with the seed books and points
# E2E_URL here. The books are put back before every test.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.7.0/BGjQKbG9U3V8cH6mRbypUAFVqFoVEu6n9bsA3QmFL1f4.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
}

import http.Request
import http.Response
import pf.Env
import pf.Http
import spec.Assert

main! = |_args| {
	base = Env.var_str!("E2E_URL") ?? "http://127.0.0.1:8927"
	ask! = |method, path, headers, body| send!(base, method, path, headers, body)

	# --- Methods ---

	# A page takes GET, and HEAD gets GET's answer without its body, with
	# the length GET's body has.
	home = ask!(GET, "/", [], "")?
	Assert.eq(Response.status(home), 200) ? |e| HomeShouldLoad(Str.inspect(e))
	Assert.contains(body(home), "Pride and Prejudice") ? |e| HomeShouldListTheBooks(Str.inspect(e))
	Assert.contains(body(home), "joy-model") ? |e| HomeShouldCarryTheFlags(Str.inspect(e))
	head = ask!(HEAD, "/", [], "")?
	Assert.eq((Response.status(head), body(head)), (200, "")) ? |e| HeadShouldAnswerWithoutABody(Str.inspect(e))
	Assert.eq(header(head, "content-length"), Response.body(home).len().to_str()) ? |e| HeadShouldReportTheLengthOfGet(Str.inspect(e))

	# Any other method is a 405 that names the ones the route takes.
	put = ask!(PUT, "/", [], "")?
	Assert.eq((Response.status(put), header(put, "allow")), (405, "GET, HEAD")) ? |e| PutShouldBeA405(Str.inspect(e))
	loan_put = ask!(PUT, "/api/books/1/loan", [], "")?
	Assert.eq((Response.status(loan_put), header(loan_put, "allow")), (405, "POST, DELETE")) ? |e| LoanPutShouldBeA405(Str.inspect(e))

	# --- Health checks ---

	# Both answer while the server runs. They are the platform's own routes,
	# outside the routing table, so no Route names them.
	for path in ["/health/live", "/health/ready"] {
		Assert.eq(Response.status(ask!(GET, path, [], "")?), 200) ? |e| HealthCheckShouldAnswer(path, Str.inspect(e))
	}

	# --- Not found ---

	# A missing page is a 404 in the same shell as every page, so it has
	# the same stylesheet (and font), but no client.
	missing = ask!(GET, "/nowhere", [], "")?
	Assert.eq(Response.status(missing), 404) ? |e| MissingPageShouldBeA404(Str.inspect(e))
	Assert.contains(body(missing), "Page not found") ? |e| MissingPageShouldSaySo(Str.inspect(e))
	Assert.contains(body(missing), "/assets/style.css") ? |e| MissingPageShouldUseTheStylesheet(Str.inspect(e))
	Assert.not_contains(body(missing), "/assets/app.js") ? |e| MissingPageShouldNotLoadTheClient(Str.inspect(e))
	# It has the same menu as the app's pages (shared/Partial/Menu.roc), with
	# no entry marked.
	Assert.contains(body(missing), "href=\"/loans\"") ? |e| MissingPageShouldHaveTheMenu(Str.inspect(e))
	Assert.not_contains(body(missing), "aria-current") ? |e| MissingPageShouldMarkNoEntry(Str.inspect(e))
	for path in ["/books/99", "/books/abc", "/books/007"] {
		Assert.eq(Response.status(ask!(GET, path, [], "")?), 404) ? |e| NoSuchBookPageShouldBeA404(path, Str.inspect(e))
	}

	# An API route answers in JSON, a missing one too.
	missing_api = ask!(GET, "/api/nowhere", [], "")?
	Assert.eq((Response.status(missing_api), body(missing_api)), (404, "{\"error\":\"There is no such endpoint.\"}")) ? |e| MissingEndpointShouldBeAJson404(Str.inspect(e))

	# --- Request bodies ---

	# Only JSON is taken, and only the right shape of it.
	as_text = ask!(POST, "/api/books", [("Content-Type", "text/plain")], emma)?
	Assert.eq(Response.status(as_text), 415) ? |e| PlainTextShouldBeA415(Str.inspect(e))
	bad_shape = ask!(POST, "/api/books", json, "{\"title\":1}")?
	Assert.eq(Response.status(bad_shape), 400) ? |e| WrongShapeShouldBeA400(Str.inspect(e))

	# --- Adding books ---

	# Checked by the same rules the form uses.
	untitled = ask!(POST, "/api/books", json, "{\"title\":\" \",\"author\":\"Jane Austen\",\"year\":1815}")?
	Assert.eq((Response.status(untitled), body(untitled)), (422, "{\"Invalid\":\"The title is missing.\"}")) ? |e| UntitledBookShouldBeRefused(Str.inspect(e))
	added = ask!(POST, "/api/books", json, emma)?
	Assert.eq((Response.status(added), body(added)), (201, "{\"author\":\"Jane Austen\",\"availability\":\"OnShelf\",\"id\":9,\"title\":\"Emma\",\"year\":1815}")) ? |e| BookShouldBeAdded(Str.inspect(e))

	# --- Loans ---

	# Borrowing takes an email, checked by the same rules the page uses.
	no_email = ask!(POST, "/api/books/1/loan", json, "{\"email\":\" \"}")?
	Assert.eq((Response.status(no_email), body(no_email)), (422, "{\"BadEmail\":\"Fill in your email.\"}")) ? |e| MissingEmailShouldBeRefused(Str.inspect(e))
	bad_email = ask!(POST, "/api/books/1/loan", json, "{\"email\":\"ben\"}")?
	Assert.eq(Response.status(bad_email), 422) ? |e| BadEmailShouldBeRefused(Str.inspect(e))

	borrowed = ask!(POST, "/api/books/1/loan", json, "{\"email\":\" ben@example.com \"}")?
	Assert.eq((Response.status(borrowed), body(borrowed)), (200, "{\"author\":\"Jane Austen\",\"availability\":\"OnLoan\",\"id\":1,\"title\":\"Pride and Prejudice\",\"year\":1813}")) ? |e| BorrowShouldSucceed(Str.inspect(e))

	# A book that is out cannot be borrowed again, by anyone.
	again = ask!(POST, "/api/books/1/loan", json, "{\"email\":\"cy@example.com\"}")?
	Assert.eq((Response.status(again), body(again)), (409, "\"AlreadyOnLoan\"")) ? |e| SecondBorrowShouldConflict(Str.inspect(e))
	missing_book = ask!(POST, "/api/books/99/loan", json, "{\"email\":\"cy@example.com\"}")?
	Assert.eq((Response.status(missing_book), body(missing_book)), (404, "\"BookMissing\"")) ? |e| BorrowingNoBookShouldBeA404(Str.inspect(e))

	# The loans page names the borrower, trimmed. The book's own page does
	# not: neither its markup nor its flags carry the email.
	loans = ask!(GET, "/loans", [], "")?
	Assert.contains(body(loans), "ben@example.com") ? |e| LoansPageShouldNameTheBorrower(Str.inspect(e))
	book_page = ask!(GET, "/books/1", [], "")?
	Assert.contains(body(book_page), "On loan.") ? |e| BookPageShouldSayItIsOut(Str.inspect(e))
	Assert.not_contains(body(book_page), "ben@example.com") ? |e| BookPageShouldNotNameTheBorrower(Str.inspect(e))

	# --- The loans as a file ---

	# The same list as a CSV download, with the borrower's email. Not JSON:
	# a plain GET that answers with a file.
	csv = ask!(GET, "/loans.csv", [], "")?
	Assert.eq(Response.status(csv), 200) ? |e| CsvShouldDownload(Str.inspect(e))
	Assert.eq(header(csv, "content-type"), "text/csv; charset=utf-8") ? |e| CsvShouldBeCsv(Str.inspect(e))
	Assert.eq(header(csv, "content-disposition"), "attachment; filename=\"loans.csv\"") ? |e| CsvShouldBeAnAttachment(Str.inspect(e))
	Assert.eq(body(csv), "title,author,email\r\nPride and Prejudice,Jane Austen,ben@example.com\r\n") ? |e| CsvShouldListTheLoan(Str.inspect(e))
	csv_post = ask!(POST, "/loans.csv", [], "")?
	Assert.eq((Response.status(csv_post), header(csv_post, "allow")), (405, "GET, HEAD")) ? |e| CsvShouldOnlyBeFetched(Str.inspect(e))

	# Giving back puts the book on the shelf, and giving back a book that
	# is already there leaves it there.
	for round in ["first", "second"] {
		given_back = ask!(DELETE, "/api/books/1/loan", [], "")?
		Assert.eq((Response.status(given_back), body(given_back)), (200, "{\"author\":\"Jane Austen\",\"availability\":\"OnShelf\",\"id\":1,\"title\":\"Pride and Prejudice\",\"year\":1813}")) ? |e| GiveBackShouldPutItBack(round, Str.inspect(e))
	}
	Assert.not_contains(body(ask!(GET, "/loans", [], "")?), "ben@example.com") ? |e| GivenBackBookShouldLeaveTheLoans(Str.inspect(e))

	Ok({})
}

json : List((Str, Str))
json = [("Content-Type", "application/json")]

emma : Str
emma = "{\"title\":\" Emma \",\"author\":\"Jane Austen\",\"year\":1815}"

send! = |base, method, path, headers, request_body| {
	request = headers.fold(
		Request.from_method(method).with_uri("${base}${path}"),
		|req, (name, value)| req.add_header(name, value),
	)
	Http.send!(request.with_body(request_body.to_utf8()), {})
}

body = |response| Str.from_utf8_lossy(Response.body(response))

header = |response, name|
	match Response.headers(response).find_first(|h| h.name.with_ascii_lowercased() == name) {
		Ok(found) => found.value
		Err(_) => ""
	}
