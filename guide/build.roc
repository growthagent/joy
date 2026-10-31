#!/usr/bin/env roc
# Run:
#
#   ./build.roc
#
# From guide/, to write the guide's page into `www/index.html`:
# page.html with the index and every topic rendered into it (see Page).
# Serve www/ and open it to read the guide. The Deploy docs workflow
# publishes www/ at the root of the GitHub Pages site.
app [main!] {
	html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
	parser: "https://github.com/lukewilliamboswell/roc-parser/releases/download/3.0.0/6xsRdRqenJrAb4wG7HaST4Xh349vD5sHAJDsKTK6E3dr.tar.zst",
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
}

import pf.Path
import pf.Stderr
import /Page

main! = |_args| {
	template = Path.utf8("page.html").read_utf8!()?
	match Page.fill(template) {
		Ok(page) => Path.utf8("www/index.html").write_utf8!(page)
		Err(NoMarker(marker)) => {
			Stderr.line!("error: page.html has no ${marker} to fill") ?? {}
			Err(Exit(1))
		}
	}
}
