import html.Html exposing [code, h1, h2, p, text]
import html.Attribute exposing [class]
import /Doc

## The topic "State as types".
StateTypes := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Structuring for scale")]),
		h1([], [text("State as types")]),
		p(
			[class("lead")],
			[
				text("When something can be in one of a few states, write those states as a tag union. Then the states that make no sense cannot be written at all."),
			],
		),
		h2([], [text("Booleans that can contradict each other")]),
		Doc.code(
			Roc,
			"",
			\\# Two flags and an error text that can contradict each other:
			\\# sending and sent at once, an error after success.
			\\Model : { sending : Bool, sent : Bool, error : Str }
			\\
			\\# Exactly the four states there are.
			\\Status : [Editing, Sending, Sent, Failed(Str)]
			\\Model : { status : Status }
		),
		p(
			[],
			[
				text("The view now matches on "),
				code([], [text("status")]),
				text(", and the compiler makes sure every state has a view. Shelf does this for the catalog's search, "),
				code([], [text("[Done, Searching, Failed(Str)]")]),
				text(", and for a book page's request, "),
				code([], [text("[Idle, Saving, Failed(Str)]")]),
				text("."),
			],
		),
		h2([], [text("No placeholder values")]),
		p(
			[],
			[
				text("An empty string for \"nothing chosen\" or a "),
				code([], [text("0")]),
				text(" for \"closed\" are states the type does not know about. Name them instead:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\# A booking dialog with placeholders:
			\\# showing_id 0 means closed, slot_id "" means nothing picked,
			\\# and loading, error and slots can all be set at once.
			\\Booking : { showing_id : I64, slot_id : Str, loading : Bool, error : Str, slots : List(Slot) }
			\\
			\\# The same dialog with its states named:
			\\Booking : [Closed, Open(Dialog)]
			\\
			\\Dialog : { showing : Showing, slots : Slots, contact : Contact, status : Status }
			\\
			\\Slots : [Loading, LoadFailed(Str), Loaded(List(Slot), Step)]
			\\
			\\Step : [Picking, Picked(Slot), Details(Slot)]
		),
		p(
			[],
			[
				text("Now a slot can only be picked once the slots have loaded, and the details form can only be filled in for a chosen slot. The view and the update match on these states, and there is no state left for the code to forget."),
			],
		),
		h2([], [text("One source of truth")]),
		p(
			[],
			[
				text("Keep each fact in one place and compute the rest. Whether the form can be sent is a function of its fields, not another field that has to be kept in step:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\is_complete : Contact -> Bool
			\\is_complete = |c| !Str.is_empty(c.name) and is_valid_email(c.email) and c.consent
		),
		p(
			[],
			[
				text("Feldman's talk Making Impossible States Impossible walks through this way of thinking in depth."),
			],
		),
	]
}
