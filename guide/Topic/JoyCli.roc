import html.Html exposing [a, code, div, h1, h2, li, p, strong, table, tbody, td, text, th, thead, tr, ul]
import html.Attribute exposing [class, href]
import /Doc

## The topic "The ./joy command".
JoyCli := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Reference")]),
		h1([], [text("The ./joy command")]),
		p(
			[class("lead")],
			[
				text("Every Joy project has "),
				code([], [text("./joy")]),
				text(" in its root, a small program that knows which release the project is on. It finds the bundles in "),
				code([], [text("client/")]),
				text(" by their headers and never needs to be told which they are."),
			],
		),
		h2([], [text("Getting it")]),
		p(
			[],
			[
				text("Make a folder for your project, and run "),
				code([], [text("roc run --opt=speed <the CLI's release URL> init")]),
				text(" in it. It shows the templates the release ships, a single-page app and a full-stack app with no database, SQLite or Postgres, lets you pick one with the arrow keys, writes it and installs "),
				code([], [text("./joy")]),
				text(". "),
				code([], [text("--template <name>")]),
				text(" picks one without asking, which is how a script or CI does it. In a directory that already has an app, "),
				code([], [text("init")]),
				text(" only installs "),
				code([], [text("./joy")]),
				text(", and then checks that your Roc matches the release. "),
				code([], [text("./joy")]),
				text(" is built for your machine, so it goes in "),
				code([], [text(".gitignore")]),
				text(", and so does "),
				code([], [text(".joy/")]),
				text(", where it keeps what it makes while you work."),
			],
		),
		h2([], [text("While you work: ./joy dev")]),
		p(
			[],
			[
				code([], [text("./joy dev")]),
				text(" builds every bundle and keeps them up to date as you save. It rebuilds only the bundles a change reaches: roc reports which files each build read, so a change in one island's modules rebuilds one bundle and a change in a shared view rebuilds every bundle that uses it. Open pages take a new build without a reload and keep their state, because the new build replays the messages the page has seen so far. A build that fails shows roc's report over the page until one succeeds. Bundles build at "),
				code([], [text("--opt=size")]),
				text(", like the ones that ship, since roc's dev backend can make a wasm too large for the browser to compile, and a server "),
				code([], [text("./joy dev")]),
				text(" starts builds at "),
				code([], [text("--opt=dev")]),
				text(", which takes seconds."),
			],
		),
		p(
			[],
			[
				text("Its builds go to "),
				code([], [text(".joy/dev/")]),
				text(", never to "),
				code([], [text("dist/")]),
				text(". "),
				code([], [text("./joy build")]),
				text(" can run at the same time, from a test run say, and a build made for hot reloading can never be deployed by mistake. "),
				code([], [text(".joy/dev/")]),
				text(" holds only what "),
				code([], [text("./joy dev")]),
				text(" builds, "),
				code([], [text("joy.js")]),
				text(" and the bundles, and an "),
				code([], [text("assets.json")]),
				text(" whose names are all plain and which says where each file lives. "),
				code([], [text("public/")]),
				text(" and "),
				code([], [text("assets/")]),
				text(" are served from where they are, so nothing is copied and a file is served the moment you save it. Development and production differ in the names alone, so a page loads its files from the same addresses in both."),
			],
		),
		p([], [text("Who serves the pages depends on the project:")]),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead(
							[],
							[
								tr(
									[],
									[
										th([], [text("The project")]),
										th([], [text("What "), code([], [text("./joy dev")]), text(" runs")]),
									],
								),
							],
						),
						tbody(
							[],
							[
								tr(
									[],
									[
										td([], [text("has no server")]),
										td(
											[],
											[
												text("A server for "),
												code([], [text("public/")]),
												text(", "),
												code([], [text("assets/")]),
												text(" and the bundles, at "),
												code([], [text("http://localhost:8000")]),
												text(" or the next free port. A path without an extension answers "),
												code([], [text("index.html")]),
												text(", so an app that changes the URL survives a refresh."),
											],
										),
									],
								),
								tr(
									[],
									[
										td([], [text("has "), code([], [text("server/main.roc")])]),
										td(
											[],
											[
												text("Your server, serving the files "),
												code([], [text(".joy/dev/assets.json")]),
												text(" lists, rebuilt and restarted when a file it reads changes, and a dev server of its own for the reload events."),
											],
										),
									],
								),
								tr(
									[],
									[
										td(
											[],
											[
												text("is started with "),
												code([], [text("--server FILE")]),
												text(", as often as needed"),
											],
										),
										td(
											[],
											[
												text("Those servers instead of "),
												code([], [text("server/main.roc")]),
												text(", started and stopped together."),
											],
										),
									],
								),
								tr(
									[],
									[
										td([], [text("is started with "), code([], [text("--no-server")])]),
										td(
											[],
											[
												text("Only the dev server, for the reload events. Your own server, run on its own, points itself at "),
												code([], [text(".joy/dev/assets.json")]),
												text("."),
											],
										),
									],
								),
							],
						),
					],
				),
			],
		),
		p(
			[],
			[
				text("A server that "),
				code([], [text("./joy dev")]),
				text(" starts finds "),
				code([], [text(".joy/dev/assets.json")]),
				text(" in "),
				code([], [text("JOY_ASSETS_JSON")]),
				text(" and serves the files it lists from where they are, as it serves the files of "),
				code([], [text("dist/assets.json")]),
				text(" from "),
				code([], [text("dist/client/")]),
				text(" in production. Nothing else in your server knows it is in development."),
			],
		),
		p(
			[],
			[
				text("When you change a file in "),
				code([], [text("public/")]),
				text(" or "),
				code([], [text("assets/")]),
				text(", open pages do what fits how they used it:"),
			],
		),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead([], [tr([], [th([], [text("What changed")]), th([], [text("What the page does")])])]),
						tbody(
							[],
							[
								tr(
									[],
									[
										td(
											[],
											[
												text("a stylesheet linked from outside any bundle root, usually in the head"),
											],
										),
										td(
											[],
											[
												text("Takes the new styles in place, without a reload, so nothing on the page changes but the styles."),
											],
										),
									],
								),
								tr(
									[],
									[
										td(
											[],
											[
												text("anything else the page loaded: an image, a script, a font, a page in "),
												code([], [text("public/")]),
											],
										),
										td([], [text("Reloads, and replays what you did, as after a server change.")]),
									],
								),
								tr([], [td([], [text("a file the page never loaded")]), td([], [text("Nothing.")])]),
							],
						),
					],
				),
			],
		),
		p(
			[],
			[
				text("A reload asks for the same plain names again, so whatever serves the files in development must make the browser revalidate with "),
				code([], [text("Cache-Control: no-cache")]),
				text(", or a reload can show an old copy. basic-webserver's file serving does that by default, and the dev server too. A proxy in front, like Caddy, needs the header added in development, and the console warns when it is missing."),
			],
		),
		p(
			[],
			[
				text("When your server changes, open pages reload once the new server answers, and each bundle replays what you did on the new markup, so typed text and open dialogs stay. Requests are not replayed from the recording, because the server that answered them is the one you just edited. A GET that is the same as before is sent again and the replay goes on with the new answer. Any other GET is sent and ends the replay. Anything else, a POST say, ends the replay before it, so nothing is sent twice. The console says where the replay stopped and why."),
			],
		),
		p(
			[],
			[
				text("A client-only app whose data comes from a backend of its own, a Rails or a Go API say, can have "),
				code([], [text("./joy dev")]),
				text(" forward its requests, so the app calls the same "),
				code([], [text("/api")]),
				text(" paths while you work as in production, and the backend needs no CORS headers:"),
			],
		),
		Doc.code(
			Sh,
			"",
			\\$ ./joy dev --proxy /api=http://localhost:3000
		),
		p(
			[],
			[
				code([], [text("--proxy")]),
				text(" can be given as often as needed. It forwards whole answers, so streamed answers, server-sent events and WebSockets do not go through it. A setup with several backends puts a reverse proxy like Caddy in front instead."),
			],
		),
		p(
			[],
			[
				code([], [text("--no-hot")]),
				text(" builds what ships instead, and the page reloads after each rebuild. Reach for it when a bug might live in the difference: a hot build records every message, and its wasm is larger."),
			],
		),
		p(
			[],
			[
				code([], [text("--watch COMMAND")]),
				text(" runs a command in your shell alongside the builds until Ctrl-C, for a compiler that writes into "),
				code([], [text("assets/")]),
				text(", and "),
				code([], [text("./joy build --before COMMAND")]),
				text(" runs one first and stops if it fails. "),
				a([href("#optimizing-assets")], [text("Optimizing assets")]),
				text(" has the rest."),
			],
		),
		h2([], [text("Ports")]),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead([], [tr([], [th([], [text("Setting")]), th([], [text("What it is")])])]),
						tbody(
							[],
							[
								tr(
									[],
									[
										td([], [code([], [text("JOY_PORT")]), text(", "), code([], [text("--port")])]),
										td(
											[],
											[
												text("Where "),
												code([], [text("./joy dev")]),
												text(" serves your pages in a project without a server. 8000, or the next free port."),
											],
										),
									],
								),
								tr(
									[],
									[
										td(
											[],
											[
												code([], [text("JOY_EVENTS_PORT")]),
												text(", "),
												code([], [text("--events-port")]),
											],
										),
										td(
											[],
											[
												text("The dev server's port when your own server serves the pages. By default the system picks a free one from the range it keeps for that, so it never takes 8000 or a port your servers are likely to use, and "),
												code([], [text("./joy")]),
												text(" asks for the same one next time, so open pages reconnect after a restart. Set it when your server runs on its own and has to know it."),
											],
										),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("JOY_HOST")]), text(", "), code([], [text("--host")])]),
										td(
											[],
											[
												text("The address to listen on, "),
												code([], [text("localhost")]),
												text(" by default. Set it to open the pages from a phone."),
											],
										),
									],
								),
							],
						),
					],
				),
			],
		),
		h2([], [text("What ships: ./joy build")]),
		p(
			[],
			[
				strong(
					[],
					[
						code(
							[],
							[
								text("./joy build [--debug] [--opt=LEVEL] [--before COMMAND] [--out-dir DIR] [--public-dir DIR] [--jobs N] [--no-server] [--server-opt=LEVEL] [--server-target=TARGET] [DIR|BUNDLE...] [-- ROC FLAGS]"),
							],
						),
					],
				),
				text(" builds what you deploy. It empties the output directory, "),
				code([], [text("dist/")]),
				text(" unless "),
				code([], [text("--out-dir")]),
				text(" names another, copies "),
				code([], [text("public/")]),
				text(" into its "),
				code([], [text("client/")]),
				text(" as it is and "),
				code([], [text("assets/")]),
				text(" under hashed names, builds the bundles there, writes "),
				code([], [text("joy.js")]),
				text(" with the browser code of exactly the features they call, and prints each bundle with its size. Bundles build at "),
				code([], [text("--opt=size")]),
				text(", which in Joy's benchmarks makes the smallest wasm without running slower, unless "),
				code([], [text("--opt")]),
				text(" picks another level. Bundles that need different levels go to different output directories, one run each."),
			],
		),
		p(
			[],
			[
				code([], [text("joy.js")]),
				text(" and every wasm are named by a hash of their content, so a host can cache them for good and a deploy never leaves a page on a stale wasm. In the HTML files it copies from "),
				code([], [text("public/")]),
				text(", the build rewrites the references to "),
				code([], [text("joy.js")]),
				text(" and to files in "),
				code([], [text("assets/")]),
				text(" to the hashed names, and gives each bundle root on the page its wasm's URL and a preload. Your pages keep saying "),
				code([], [text("./joy.js")]),
				text(", which is what "),
				code([], [text("./joy dev")]),
				text(" serves."),
			],
		),
		p(
			[],
			[
				text("Your own files go in one of two folders, and the folder decides what the build does with them:"),
			],
		),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead(
							[],
							[
								tr([], [th([], [text("Folder")]), th([], [text("For")]), th([], [text("In a build")])]),
							],
						),
						tbody(
							[],
							[
								tr(
									[],
									[
										td([], [code([], [text("public/")])]),
										td(
											[],
											[
												text("Addresses other people hold, like "),
												code([], [text("robots.txt")]),
												text(", "),
												code([], [text("favicon.ico")]),
												text(" and a PDF linked from emails, files someone else named or hashed already, and large media."),
											],
										),
										td(
											[],
											[
												text("Copied byte for byte, at the same path. Never read and never hashed."),
											],
										),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("assets/")])]),
										td(
											[],
											[
												text("What your own pages link to and nothing outside does: stylesheets, fonts, images, scripts."),
											],
										),
										td(
											[],
											[
												text("One copy each in "),
												code([], [text("dist/client/")]),
												text(", at its own path with a hash of its content in its name, "),
												code([], [text("css/site.3f9a1c2b.css")]),
												text(". A stylesheet's "),
												code([], [text("url()")]),
												text(" to another file in "),
												code([], [text("assets/")]),
												text(" is rewritten to the hashed name."),
											],
										),
									],
								),
							],
						),
					],
				),
			],
		),
		p(
			[],
			[
				text("Roc code names a file with a string literal that the compiler checks, "),
				code([], [text("Asset")]),
				text(" for "),
				code([], [text("assets/")]),
				text(" and "),
				code([], [text("Public")]),
				text(" for "),
				code([], [text("public/")]),
				text(", so a misspelled name is a compile error. An asset gets its hashed name in a build and the plain one while you work, so editing a stylesheet rebuilds nothing. Say once where "),
				code([], [text("client/")]),
				text(" is served, the same address while you work and in production, and pass the same one to "),
				code([], [text("Html.document")]),
				text(":"),
			],
		),
		Doc.code(
			Roc,
			"",
			\\client_url : Str
			\\client_url = "/"
			\\
			\\asset : Asset -> Str
			\\asset = |file| "\${client_url}\${Asset.path(file)}"
			\\
			\\link([rel("stylesheet"), href(asset("css/site.css"))])
		),
		p(
			[],
			[
				text("A file in "),
				code([], [text("assets/")]),
				text(" that names other files in a way the build does not rewrite, like a web app manifest's icons, is better served by your server, which names its files through "),
				code([], [text("Asset")]),
				text(", or goes into "),
				code([], [text("public/")]),
				text(" together with the files it names."),
			],
		),
		p(
			[],
			[
				text("A server writes the script tag, the preloads and the roots' wasm URLs itself, so it needs the hashed names too. When the project has "),
				code([], [text("server/main.roc")]),
				text(", "),
				code([], [text("./joy build")]),
				text(" builds the server at the same time as the bundles, at "),
				code([], [text("--opt=speed")]),
				text(". Every build writes the hashed names into "),
				code([], [text("dist/assets.json")]),
				text(", the name of "),
				code([], [text("joy.js")]),
				text(", of each bundle's wasm and of each file in "),
				code([], [text("assets/")]),
				text(", as plain JSON that any other tool can read too. The binary goes to "),
				code([], [text("dist/server/main")]),
				text(", beside "),
				code([], [text("dist/client/")]),
				text(", which holds everything public. Your server serves "),
				code([], [text("dist/client/")]),
				text(", never "),
				code([], [text("dist/")]),
				text(", so its own binary can never be downloaded, and you deploy "),
				code([], [text("dist/")]),
				text(" as one unit. The server reads "),
				code([], [text("assets.json")]),
				text(" when it starts, and the layout passes it to "),
				code([], [text("Html.document")]),
				text(" with the address "),
				code([], [text("client/")]),
				text(" is served at. The server answers a path that matches none of its pages by looking it up there, so the files can sit at the root next to your pages, each with its own cache policy: a year for a hashed name, revalidate for a plain one. While you work it reads the one in "),
				code([], [text(".joy/dev/")]),
				text(", with plain names. A server that finds no "),
				code([], [text("assets.json")]),
				text(", or one that misses one of its bundles or was made for other assets, stops at startup and says why, so a deploy that does not belong together fails at once."),
			],
		),
		ul(
			[],
			[
				li(
					[],
					[
						code([], [text("--server-opt")]),
						text(" picks another level for the server, and "),
						code([], [text("--server-target")]),
						text(" cross-compiles it, for a Linux server built on a Mac say."),
					],
				),
				li(
					[],
					[
						code([], [text("--no-server")]),
						text(" builds the bundles alone. A server built some other way, in a Nix derivation of its own say, compiles with the flag "),
						code([], [text("./joy build")]),
						text(" prints and reads the build's "),
						code([], [text("assets.json")]),
						text(" from the file "),
						code([], [text("JOY_ASSETS_JSON")]),
						text(" names."),
					],
				),
				li(
					[],
					[
						text("A project has one server that renders its pages. Two servers that serve different bundles, a public site and an internal portal say, are two Joy projects side by side, each with its own "),
						code([], [text("client/")]),
						text(", "),
						code([], [text("server/")]),
						text(" and "),
						code([], [text("./joy")]),
						text(", sharing views and types through a package both name by path. Each server can then only name its own bundles, and a typo is a compile error."),
					],
				),
			],
		),
		p(
			[],
			[
				text("A static host publishes "),
				code([], [text("dist/client/")]),
				text(", and needs to answer "),
				code([], [text("index.html")]),
				text(" for an app's own paths: Netlify with "),
				code([], [text("/* /index.html 200")]),
				text(" in "),
				code([], [text("_redirects")]),
				text(", while Cloudflare Pages does it for a site without a "),
				code([], [text("404.html")]),
				text("."),
			],
		),
		ul(
			[],
			[
				li(
					[],
					[
						code([], [text("--debug")]),
						text(" writes the whole runtime, readable and with every feature, and asks roc for debug information. It is for chasing a bug."),
					],
				),
				li([], [code([], [text("--jobs")]), text(" builds that many bundles at a time, 4 by default.")]),
				li(
					[],
					[
						text("A warning in your own files fails the build, and the warnings of downloaded packages are only printed. "),
						code([], [text("./joy dev")]),
						text(" prints warnings and carries on."),
					],
				),
				li(
					[],
					[
						text("Anything after "),
						code([], [text("--")]),
						text(" goes to roc as it is, "),
						code([], [text("-- --no-cache")]),
						text(" for instance."),
					],
				),
				li(
					[],
					[
						text("The same file in "),
						code([], [text("public/")]),
						text(" and "),
						code([], [text("assets/")]),
						text(", or a file at a path Joy writes, like "),
						code([], [text("joy.js")]),
						text(", fails the build instead of one of them silently winning."),
					],
				),
			],
		),
		p(
			[],
			[
				text("The output directory belongs to "),
				code([], [text("./joy")]),
				text(", which empties it on every build. It refuses a directory outside the project, the project itself or a parent of it, and a directory with files in it that it did not make, so a mistyped "),
				code([], [text("--out-dir")]),
				text(" cannot delete your own files."),
			],
		),
		h2([], [text("In tests")]),
		p(
			[],
			[
				text("Tests run what ships, so a test run is a build into a directory of its own, "),
				code([], [text("./joy build --out-dir .joy/test/<run>")]),
				text(", with "),
				code([], [text("--debug")]),
				text(" or another "),
				code([], [text("--opt")]),
				text(" for a second pass. Each run gets a new directory, so two passes back to back never mix, and two runs at once never replace each other's files. The directory records how it was built, which a test harness checks before it starts a browser. A run deletes its directory when it ends, and "),
				code([], [text("./joy")]),
				text(" removes the ones left by runs that died. Tests never use the builds of "),
				code([], [text("./joy dev")]),
				text(". A run that builds a server gets one of its own in its directory's "),
				code([], [text("server/")]),
				text(", which reads the run's "),
				code([], [text("assets.json")]),
				text(", and a harness with several passes can build the server once and point it at each pass's "),
				code([], [text("assets.json")]),
				text(" with "),
				code([], [text("JOY_ASSETS_JSON")]),
				text("."),
			],
		),
		h2([], [text("Bundles")]),
		ul(
			[],
			[
				li(
					[],
					[
						strong([], [code([], [text("./joy new bundle <path>")])]),
						text(" writes a bundle file."),
					],
				),
				li(
					[],
					[
						strong([], [code([], [text("./joy bundles")])]),
						text(" lists the bundles, their ids and their outputs, and the Joy apps outside "),
						code([], [text("client/")]),
						text(" it does not build. "),
						code([], [text("--json")]),
						text(" prints the same for a backend in another language or a test harness."),
					],
				),
			],
		),
		h2([], [text("Releases")]),
		ul(
			[],
			[
				li(
					[],
					[
						strong([], [code([], [text("./joy versions")])]),
						text(" lists Joy's releases with their dates and the Roc each recommends, and marks the one the app and "),
						code([], [text("./joy")]),
						text(" are on."),
					],
				),
				li(
					[],
					[
						strong([], [code([], [text("./joy use <tag>")])]),
						text(" moves the app to a release: it builds that release's CLI first, then rewrites the Joy platform URL and the joy-html URL in every "),
						code([], [text(".roc")]),
						text(" file that names them: the bundles, the server, the shared package, tests and scripts. It also rewrites the packages the project names by path outside it, and says which, so a second project that shares them can follow. If the build fails, the app is left alone."),
					],
				),
				li(
					[],
					[
						strong([], [code([], [text("./joy doctor")])]),
						text(" shows the app's release, says when a newer one is out, compares your Roc with the recommended one, and reports the bundles it found, their outputs and whether "),
						code([], [text("generated/")]),
						text(" is current. It also lists the files outside "),
						code([], [text("client/")]),
						text(" on another Joy release than the app, and the files on another joy-html release than the rest."),
					],
				),
			],
		),
		p(
			[],
			[
				code([], [text("./joy")]),
				text(" always runs the CLI of the app's release, because the two have to agree on how the runtime is put together. When your app is on another release than the one "),
				code([], [text("./joy")]),
				text(" was built for, it builds that release's CLI into "),
				code([], [text(".joy/cli/")]),
				text(", once, and hands the command over to it. It never asks, since that changes none of your files, and it says so:"),
			],
		),
		Doc.code(
			Text,
			"",
			\\./joy 0.15.0 is running Joy 0.14.0, the release this app is on.
		),
		p(
			[],
			[
				text("So an old commit, a teammate with an older "),
				code([], [text("./joy")]),
				text(" and CI all get the CLI the app was written for. Moving the app to another release is always your call, with "),
				code([], [text("./joy use")]),
				text(". Bundles on different releases share one "),
				code([], [text("joy.js")]),
				text(", so they have to agree too: the build lists each bundle with its release and prints the "),
				code([], [text("./joy use")]),
				text(" command that moves them all to the newest one."),
			],
		),
		p(
			[],
			[
				code([], [text("./joy build")]),
				text(" and "),
				code([], [text("./joy dev")]),
				text(" download nothing themselves. Roc fetches the platform and the packages the first time it needs them, from the internet, or from a cache filled beforehand in a Nix build, so the same commands work in both."),
			],
		),
	]
}
