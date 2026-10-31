import html.Html exposing [a, code, div, h1, h2, p, table, tbody, td, text, th, thead, tr]
import html.Attribute exposing [class, href]
import /Doc

## The topic "Optimizing assets".
OptimizingAssets := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Reference")]),
		h1([], [text("Optimizing assets")]),
		p(
			[class("lead")],
			[
				text("The files in "),
				code([], [text("assets/")]),
				text(" and "),
				code([], [text("public/")]),
				text(" stay as you wrote them, so you can read and edit them. "),
				code([], [text("./joy build")]),
				text(" gives the ones in "),
				code([], [text("assets/")]),
				text(" hashed names and copies them, and leaves making them smaller to the tools you choose, so a project needs no JavaScript tools until it wants them."),
			],
		),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead([], [tr([], [th([], [text("The job")]), th([], [text("Files")]), th([], [text("When")])])]),
						tbody(
							[],
							[
								tr([], [td([], [text("Compile")]), td([], [text("TypeScript, Sass, Tailwind")]), td([], [text("Before the build, with --before, and while you work, with --watch")])]),
								tr([], [td([], [text("Minify")]), td([], [text("JavaScript, CSS, SVG")]), td([], [text("After the build, on dist/client/")])]),
								tr([], [td([], [text("Optimize images")]), td([], [text("PNG, JPEG")]), td([], [text("When you add an image")])]),
								tr([], [td([], [text("Compress")]), td([], [text("Anything that is text")]), td([], [text("When it is served, by your host, CDN or proxy")])]),
							],
						),
					],
				),
			],
		),
		h2([], [text("Minify what ships")]),
		p(
			[],
			[
				text("Run a minifier over the build's output. The names stay the same, so "),
				code([], [text("assets.json")]),
				text(" and the names your pages use stay right, and your own files are not touched. "),
				code([], [text("./joy dev")]),
				text(" goes on serving them as you wrote them, so they read well in the browser's devtools."),
			],
		),
		Doc.code(
			Sh,
			"",
			\\$ ./joy build
			\\$ esbuild "dist/client/**/*.css" --minify --outbase=dist/client --outdir=dist/client --allow-overwrite
		),
		p(
			[],
			[
				text("A file's hash is of what you wrote, so a change to your file gives it a new name. A new version of the minifier can change the output under the same name, which does no harm."),
			],
		),
		h2([], [text("Compile what a browser cannot read")]),
		p(
			[],
			[
				text("Keep the sources outside "),
				code([], [text("assets/")]),
				text(", since everything in it ships, and have the compiler write into it. Add what it writes to "),
				code([], [text(".gitignore")]),
				text(". Give "),
				code([], [text("./joy dev")]),
				text(" the command that keeps it up to date, and "),
				code([], [text("./joy build")]),
				text(" the one that makes it once:"),
			],
		),
		Doc.code(
			Sh,
			"",
			\\$ ./joy dev --watch "sass --watch styles:assets/css"
			\\$ ./joy build --before "sass --style=compressed --no-source-map styles:assets/css"
		),
		p(
			[],
			[
				code([], [text("--watch")]),
				text(" runs alongside the builds and stops with "),
				code([], [text("./joy dev")]),
				text(", its output marked with its program's name. "),
				code([], [text("--before")]),
				text(" runs before anything is built, and a command that fails stops the build. Both run in your shell and can be given as often as you need. A file that a watcher has yet to write can fail the first build, and "),
				code([], [text("./joy dev")]),
				text(" builds again once it appears. A compiler that minifies this way needs no step after the build."),
			],
		),
		p(
			[],
			[
				text("esbuild stops watching when its input closes, so it needs "),
				code([], [text("--watch=forever")]),
				text(":"),
			],
		),
		Doc.code(
			Sh,
			"",
			\\$ ./joy dev --watch "esbuild scripts/app.ts --bundle --outfile=assets/app.js --watch=forever"
			\\$ ./joy build --before "esbuild scripts/app.ts --bundle --minify --outfile=assets/app.js"
		),
		p(
			[],
			[
				text("Like most of these tools, esbuild removes TypeScript's types without checking them, so run "),
				code([], [text("tsc --noEmit")]),
				text(" as well. Bundle JavaScript that spans several files, as here: a build gives each file in "),
				code([], [text("assets/")]),
				text(" a hashed name and does not rewrite the imports between them, and warns about any it finds. A script that keeps its modules apart belongs in "),
				code([], [text("public/")]),
				text(", which keeps its names."),
			],
		),
		h2([], [text("Images")]),
		p(
			[],
			[
				text("Images are often the largest part of a page, and compression barely helps them, as they are compressed already. Optimizing one can change how it looks, so someone has to choose the quality. Do it when you add the image, and commit the result, or use an image CDN. An image that changes format, from PNG to WebP say, changes its name, so that happens before the build and your code uses the new name."),
			],
		),
		h2([], [text("Compression")]),
		p(
			[],
			[
				text("Brotli and gzip are for what serves your files. Many hosts and CDNs do it on their own, and a proxy like Caddy can do it or serve files you compressed ahead of time. The options of the commands are in "),
				a([href("#joy-cli")], [text("The ./joy command")]),
				text("."),
			],
		),
	]
}
