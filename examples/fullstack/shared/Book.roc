## The book types that cross the wire, in the flags and in the JSON API, and
## the rules a new book and a borrower must follow, which both sides check
## with the same code: the client before it sends, so a mistake shows at
## once, and the server again, because a request can come from anywhere.
Book := [].{
	## A book in a list: the catalog and a search.
	Summary : { id : I64, title : Str, author : Str, availability : Availability }

	## A book's own page. `availability` says whether the book is out, never
	## who has it: the book page is public, the borrower's email is not.
	Detail : { id : I64, title : Str, author : Str, year : I64, availability : Availability }

	## Whether a book is on the shelf or out.
	Availability : [OnShelf, OnLoan]

	## A book that is out, and the email it was borrowed with, for the
	## page that lists the loans.
	Loan : { id : I64, title : Str, author : Str, email : Str }

	## What someone fills in to add a book.
	New : { title : Str, author : Str, year : I64 }

	## What someone fills in to borrow a book.
	Borrower : { email : Str }

	## The book trimmed, or what is wrong with it, in words for the person
	## who filled in the form.
	check : Book.New -> Try(Book.New, Str)
	check = |book| {
		title = book.title.trim()
		author = book.author.trim()
		if title.is_empty() {
			Err("The title is missing.")
		} else if author.is_empty() {
			Err("The author is missing.")
		} else if book.year < 1 or book.year > 2100 {
			Err("The year must be between 1 and 2100.")
		} else {
			Ok({ title: title, author: author, year: book.year })
		}
	}

	## The borrower with the email trimmed, or what is wrong with it. An
	## email is only checked for its shape (something, an @, a domain with a
	## dot): whether it reaches anyone is not knowable here.
	check_borrower : Book.Borrower -> Try(Book.Borrower, Str)
	check_borrower = |borrower| {
		email = borrower.email.trim()
		if email.is_empty() {
			Err("Fill in your email.")
		} else if email.count_utf8_bytes() > 254 or !looks_like_email(email) {
			Err("That does not look like an email address.")
		} else {
			Ok({ email: email })
		}
	}
}

looks_like_email : Str -> Bool
looks_like_email = |email|
	match email.split_on("@") {
		[local, domain] => {
			dotted = domain.contains(".") and !domain.starts_with(".") and !domain.ends_with(".")
			!local.is_empty() and dotted and !email.contains(" ")
		}

		_ => Bool.False
	}

expect Book.check({ title: " Emma ", author: "Jane Austen", year: 1815 }) == Ok({ title: "Emma", author: "Jane Austen", year: 1815 })
expect Book.check({ title: "  ", author: "Jane Austen", year: 1815 }) == Err("The title is missing.")
expect Book.check({ title: "Emma", author: "", year: 1815 }) == Err("The author is missing.")
expect Book.check({ title: "Emma", author: "Jane Austen", year: 0 }) == Err("The year must be between 1 and 2100.")
expect Book.check({ title: "Emma", author: "Jane Austen", year: 2101 }) == Err("The year must be between 1 and 2100.")

expect Book.check_borrower({ email: " ben@example.com " }) == Ok({ email: "ben@example.com" })
expect Book.check_borrower({ email: "   " }) == Err("Fill in your email.")
expect Book.check_borrower({ email: "ben" }).is_err()
expect Book.check_borrower({ email: "@example.com" }).is_err()
expect Book.check_borrower({ email: "ben@example" }).is_err()
expect Book.check_borrower({ email: "ben@.com" }).is_err()
expect Book.check_borrower({ email: "ben@example." }).is_err()
expect Book.check_borrower({ email: "ben@a@example.com" }).is_err()
expect Book.check_borrower({ email: "ben smith@example.com" }).is_err()
expect Book.check_borrower({ email: "${Str.repeat("a", 250)}@example.com" }).is_err()
