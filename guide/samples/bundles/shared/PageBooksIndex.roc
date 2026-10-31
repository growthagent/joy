import html.Html exposing [text]

PageBooksIndex := [].{
	Model : { count : I64 }

	Msg : [Bump]

	view : Model -> Html(Msg)
	view = |model| text(model.count.to_str())
}
