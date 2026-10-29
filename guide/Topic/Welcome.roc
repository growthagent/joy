import html.Html exposing [code, div, h1, h2, li, p, span, strong, text, ul]
import html.Attribute exposing [class]
import /Doc

## The topic "What is Joy?".
Welcome := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Start here")]),
		h1([], [text("What is Joy?")]),
		p(
			[class("lead")],
			[
				text("Joy is a framework for building web apps in Roc. Your app compiles to WebAssembly and runs in the browser, and the same Roc code that draws a page there can draw it on the server."),
			],
		),
		p(
			[],
			[
				text("A Joy app is written in the shape that Elm made popular, often called The Elm Architecture. All of the app's state lives in one value, the "),
				strong([], [text("model")]),
				text(". Things that happen arrive as "),
				strong([], [text("messages")]),
				text(". A function called "),
				code([], [text("update")]),
				text(" turns a model and a message into the next model, and a function called "),
				code([], [text("view")]),
				text(" turns a model into HTML. Joy does the rest: it listens for events, calls your functions, and changes only the parts of the page that need to change."),
			],
		),
		h2([], [text("What you get")]),
		ul(
			[],
			[
				li(
					[],
					[
						strong([], [text("The platform.")]),
						text(" The Roc platform your app runs on. It gives you effects and subscriptions for HTTP, timers, the keyboard, the DOM, ports to JavaScript, Web Crypto and media recording."),
					],
				),
				li(
					[],
					[
						strong([], [text("joy-html.")]),
						text(" A package with the "),
						code([], [text("Html")]),
						text(" and "),
						code([], [text("Attribute")]),
						text(" types. The server and the browser use the same types, so one view can be rendered on either side."),
					],
				),
				li(
					[],
					[
						strong([], [text("joy.js.")]),
						text(" The one script a page includes: the runtime that runs a bundle, with the browser code of the features your bundles call, and the few lines that mount every bundle the page names. "),
						code([], [text("runtime.js")]),
						text(" is the same runtime as a library, for embedding a bundle by hand."),
					],
				),
				li(
					[],
					[
						strong([], [text("./joy.")]),
						text(" The command line. It finds the bundles in your project, builds them, hot reloads them into open pages while you work, and keeps your app and itself on a Joy release."),
					],
				),
			],
		),
		h2([], [text("How this guide is laid out")]),
		p(
			[],
			[
				strong([], [text("Start here")]),
				text(" builds a browser app one idea at a time: the update loop, views, effects, subscriptions and flags. "),
				strong([], [text("Growing an app")]),
				text(" covers what changes when an app has several pages and a server: three folders, server rendering, bundles, routes and typed endpoints. "),
				strong([], [text("Structuring for scale")]),
				text(" is about the decisions that keep a large app pleasant to work in: how to reuse a piece of UI, when something should have its own model, and how to let types do the checking for you. Much of that part comes from the Elm community, where these questions were worked out first."),
			],
		),
		div(
			[class("note")],
			[
				span([class("note-label")], [text("Before you start")]),
				text(" "),
				p(
					[],
					[
						text("Joy is in early development. The API still changes between releases, so when an example here does not compile, compare it with the examples in the Joy repository, which are kept building against the current platform."),
					],
				),
			],
		),
		h2([], [text("Running the examples")]),
		p(
			[],
			[
				text("Clone the Joy repository and enter its development shell with "),
				code([], [text("nix develop")]),
				text(", which gives you the right Roc compiler, Rust and the other tools. Without Nix, the README lists what to install. Then run any example:"),
			],
		),
		Doc.code(
			Sh,
			"in the joy repository",
			\\$ ./watch.roc examples/counter.roc
		),
		p(
			[],
			[
				text("The app is now at "),
				code([], [text("http://localhost:8000")]),
				text(". The example is rebuilt when you save it, and a refresh shows the change."),
			],
		),
	]
}
