import vibe.d;

struct TranslationContext
{
	import std.typetuple : TypeTuple;

	alias languages = TypeTuple!("en_US", "fr_FR", "nl");
	mixin translationModule!"text";

	static string determineLanguage(HTTPServerRequest req)
	{
		import std.string : split, replace;

		auto acc_lang = "Accept-Language" in req.headers;
		if (acc_lang)
			return replace(split(*acc_lang, ",")[0], "-", "_");
		return null;
	}
}

void renderI18nTemplate(string file)(HTTPServerRequest req, HTTPServerResponse res)
{
	switch (TranslationContext.determineLanguage(req)) {
		default:
		static string diet_translate__(string key, string context=null)
		{
			return tr!(TranslationContext, TranslationContext.languages[0])(key);
		}
		render!("index.dt", req, diet_translate__)(res);
		break;

		foreach (lang; TranslationContext.languages) {
			case lang:
			mixin("struct " ~ lang ~ " {
				static string diet_translate__(string key, string context=null) {
					return tr!(TranslationContext, lang)(key);
				}
			}
			alias translate = " ~ lang ~ ".diet_translate__;");
			render!(file, req, translate)(res);
			break;
		}
	}
}

HTTPServerRequestDelegate staticI18nTemplate(string file)()
{
	return (HTTPServerRequest req, HTTPServerResponse res) {
		renderI18nTemplate!(file)(req, res);
	};
}

string filterDCode(string text, size_t indent) {
	import std.regex;
	import std.array;

	auto dst = appender!string;
	filterHTMLEscape(dst, text, HTMLEscapeFlags.escapeQuotes);
	auto regex = regex(r"(^|\s)(if|return)(;|\s)");
	text = replaceAll(dst.data, regex, `$1<span class="keyword">$2</span>$3`);

	auto indent_string = "\n" ~ "\t".replicate(indent);

	auto ret = appender!string();
	ret ~= indent_string ~ "<pre>\n"
			~ text
			~ indent_string ~ "</pre>";

	return ret.data;
}

shared static this()
{
	registerDietTextFilter("dcode", &filterDCode);

	auto router = new URLRouter;
	router.get("/", staticI18nTemplate!"index.dt");
	router.get("*", serveStaticFiles("public/"));

	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	listenHTTP(settings, router);

	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}
