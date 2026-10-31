import html.Html exposing [code, h1, p, text]
import html.Attribute exposing [class]
import /Doc

## The topic "Flags".
Flags := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Start here")]),
		h1([], [text("Flags")]),
		p(
			[class("lead")],
			[
				text("Flags are the data an app starts from. The page writes them on the bundle's root element, and "),
				code([], [text("init")]),
				text(" receives them as a string."),
			],
		),
		Doc.code(
			Html,
			"public/index.html",
			\\<div data-joy-bundle="app" data-joy-flags='{"name": "Brödil", "karma": 99}'></div>
			\\<script type="module" src="./joy.js"></script>
		),
		p(
			[],
			[
				code([], [text("joy.js")]),
				text(" is the loader "),
				code([], [text("./joy build")]),
				text(" writes next to your bundles, with the runtime built into it, so it is the only script a page loads. The build copies "),
				code([], [text("public/")]),
				text(" in beside it, which is why the page can name it as "),
				code([], [text("./joy.js")]),
				text(". It mounts a bundle on every element that names one, with the flags on that element, by calling the runtime's "),
				code([], [text("mount")]),
				text(". You can import "),
				code([], [text("mount")]),
				text(" from "),
				code([], [text("runtime.js")]),
				text(" and call it yourself instead when you embed a bundle by hand."),
			],
		),
		p(
			[],
			[
				text("Flags are usually JSON. "),
				code([], [text("Json.parse")]),
				text(" decodes them into the type the code expects, and a mismatch is an error you can show instead of a crash:"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\Model : [
			\\    Human({ name : Str, karma : I32 }),
			\\    FailedToParseFlags(Str),
			\\]
			\\
			\\init : Str -> (Model, List(Effect(Msg)))
			\\init = |flags|
			\\    match Json.parse(flags) {
			\\        Ok({ name, karma }) => (Human({ name, karma }), [])
			\\        Err(problem) => (
			\\            FailedToParseFlags(flags),
			\\            [Console.log("Could not read the flags: \${Str.inspect(problem)}")],
			\\        )
			\\    }
		),
		p(
			[],
			[
				text("In a full-stack app the flags are the page's model: the server builds it, writes it on the bundle's root, and the client starts from exactly that value. That is how hydration works, in Server rendering."),
			],
		),
	]
}
