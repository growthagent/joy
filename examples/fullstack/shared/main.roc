package [Api, App, Book, PageBooksIndex, PageBooksNew, PageBooksShow, PageLoansIndex, PartialMenu, Route] {
	html: "https://github.com/niclas-ahden/joy-html/releases/download/0.17.1/AcmwFzyfbsf5RALWNdX6cXw1cuuDXt96YfcysNqgFqoG.tar.zst",
	url: "https://github.com/niclas-ahden/roc-url/releases/download/0.7.1/AuBv5v9TGGUS4yRtC8tLEVyEr7MkaReZCeuu2sYANn8F.tar.zst",
}

# Each page lives at Page/<resource>/<action>.roc, the same path its client
# and server halves have under client/ and server/. Other packages see a
# page under the flat name given here.
import /Page/Books/Index as PageBooksIndex
import /Page/Books/New as PageBooksNew
import /Page/Books/Show as PageBooksShow
import /Page/Loans/Index as PageLoansIndex
import /Partial/Menu as PartialMenu
