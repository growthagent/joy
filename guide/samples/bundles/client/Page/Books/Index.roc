import pf.Effect
import pf.Sub
import shared.PageBooksIndex

Index := [].{
	init : PageBooksIndex.Model -> (PageBooksIndex.Model, List(Effect(PageBooksIndex.Msg)))
	init = |model| (model, [])

	update : PageBooksIndex.Model, PageBooksIndex.Msg -> (PageBooksIndex.Model, List(Effect(PageBooksIndex.Msg)))
	update = |model, Bump| ({ count: model.count + 1 }, [])

	subscriptions : PageBooksIndex.Model -> List(Sub(PageBooksIndex.Msg))
	subscriptions = |_model| []
}
