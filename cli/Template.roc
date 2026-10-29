import "templates/spa/README.md" as spa_readme : Str
import "templates/spa/assets/css/site.css" as spa_site_css : Str
import "templates/spa/client/Page/About.roc" as spa_page_about : Str
import "templates/spa/client/Page/Home.roc" as spa_page_home : Str
import "templates/spa/client/Route.roc" as spa_route : Str
import "templates/spa/client/app.roc" as spa_app : Str
import "templates/spa/public/index.html" as spa_index : Str

## The projects `./joy init` starts from. Each is a folder under templates/
## and a Joy project of its own, whose bundles name this checkout's
## platform, so it builds where it is. Its files are built into ./joy.
Template :: [].{
	Template : { name : Str, description : Str, files : List((Str, Str)) }

	all : List(Template.Template)
	all = [
		{
			name: "spa",
			description: "A single-page app: pages in one bundle, with URLs and Back and Forward",
			files: [
				("README.md", spa_readme),
				("assets/css/site.css", spa_site_css),
				("client/Page/About.roc", spa_page_about),
				("client/Page/Home.roc", spa_page_home),
				("client/Route.roc", spa_route),
				("client/app.roc", spa_app),
				("public/index.html", spa_index),
			],
		},
	]

	## How a template's bundles name the platform. Init puts the project's own
	## platform in its place.
	platform_line : Str
	platform_line = "platform \"../../../../platform/main.roc\""

	## Where a template's README shows the command that installs ./joy in a
	## fresh clone. Init writes the command there.
	install_command : Str
	install_command = "JOY_INSTALL_COMMAND"
}
