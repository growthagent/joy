# Lending a book in a real browser: the email is checked before anything is
# sent, a good one lends the book, the loans page lists it with who has it,
# and giving it back puts it on the shelf again.
#
# Run via ./tests.roc, which starts a server with the seed books and points
# E2E_URL here. The books are put back before every test.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.10.0/ELCrvV4MsjnA4phYGXW3oLW2fH9y1imCxPkxhVnpW9jG.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.6.0/9ThTkhd7zrviwQpM3LvGd7pvzGhr4ZXNmWJV7pTJc9AJ.tar.zst",
}

import pf.Cmd
import pf.Env
import playwright.Playwright exposing [assert!]
import spec.Assert
import Browser

main! = |_args| {
	base = Env.var_str!("E2E_URL") ?? "http://127.0.0.1:8927"

	{ browser, page } = Playwright.launch_page_with!(
		{ new: Cmd.new_str, spawn!: Cmd.spawn_leashed! },
		{ timeout: TimeoutMilliseconds(10000) },
	)?

	page.navigate!("${base}/books/1")?
	assert!(page.find(".shelf").has_text("On the shelf.")) ? |e| BookShouldStartOnTheShelf(Str.inspect(e))
	Assert.eq(Browser.hydration!(page)?, Browser.clean_claim) ? |e| BookHydrationWasNotClean(Str.inspect(e))

	# Mistakes show at once, worded as Book.check_borrower words them.
	page.find(".borrow button").click!()?
	assert!(page.find(".book-page .error").has_text("Fill in your email.")) ? |e| MissingEmailShouldSaySo(Str.inspect(e))
	page.find("#borrow-email").fill!("ben")?
	page.find(".borrow button").click!()?
	assert!(page.find(".book-page .error").has_text("That does not look like an email address.")) ? |e| BadEmailShouldSaySo(Str.inspect(e))
	assert!(page.find(".shelf").has_text("On the shelf.")) ? |e| BadEmailShouldLendNothing(Str.inspect(e))

	# A good one lends the book, once the server has stored it.
	page.find("#borrow-email").fill!(" ben@example.com ")?
	page.find(".borrow button").click!()?
	assert!(page.find(".shelf").has_text("On loan.")) ? |e| BorrowShouldLand(Str.inspect(e))
	assert!(page.find(".give-back").is_enabled()) ? |e| GiveBackShouldBeOffered(Str.inspect(e))
	assert!(page.find(".book-page .error").is_empty()) ? |e| ErrorShouldClear(Str.inspect(e))

	# The loans page lists it with who has it, rendered by the server.
	page.find(".links a[href=\"/loans\"]").click!()?
	assert!(page.has_url("${base}/loans")) ? |e| LoansShouldOpen(Str.inspect(e))
	assert!(page.find_all(".loans .books li").has_count(1)) ? |e| LoanShouldBeListed(Str.inspect(e))
	assert!(page.find(".loans .books li a").has_text("Pride and Prejudice")) ? |e| LoanShouldBeTheBorrowedBook(Str.inspect(e))
	assert!(page.find(".loans .borrower").has_text("ben@example.com")) ? |e| LoanShouldNameTheBorrower(Str.inspect(e))
	Assert.eq(Browser.hydration!(page)?, Browser.clean_claim) ? |e| LoansHydrationWasNotClean(Str.inspect(e))

	# Giving it back takes it off the list.
	page.find(".loans .give-back").click!()?
	assert!(page.find_all(".loans .books li").has_count(0)) ? |e| GivenBackBookShouldLeaveTheList(Str.inspect(e))
	assert!(page.find(".loans .status").has_text("Nothing is on loan. Find a book in the catalog.")) ? |e| EmptyLoansShouldSaySo(Str.inspect(e))

	# And the book is on the shelf again.
	page.navigate!("${base}/books/1")?
	assert!(page.find(".shelf").has_text("On the shelf.")) ? |e| BookShouldBeBackOnTheShelf(Str.inspect(e))

	browser.close!()?
	Ok({})
}
