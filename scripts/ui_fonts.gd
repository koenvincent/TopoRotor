class_name UiFonts
extends RefCounted

# Bundled OFL fonts (Fontsource builds): Lilita One for titles and big game
# feedback, Nunito ExtraBold/Black for everything you read. Each face falls
# back to its latin-ext subset (Ł, ő, ș in European names) and then to DejaVu
# for symbols such as ★ ✓ → ❚.
const FILES = {
	"display": ["res://assets/fonts/lilita-one-latin-400-normal.woff2","res://assets/fonts/lilita-one-latin-ext-400-normal.woff2"],
	"bold": ["res://assets/fonts/nunito-latin-800-normal.woff2","res://assets/fonts/nunito-latin-ext-800-normal.woff2"],
	"black": ["res://assets/fonts/nunito-latin-900-normal.woff2","res://assets/fonts/nunito-latin-ext-900-normal.woff2"],
}
const SYMBOLS = "res://assets/interface.ttf"

static var cache: Dictionary = {}

static func font(kind: String) -> Font:
	if cache.has(kind):
		return cache[kind]
	var files: Array = FILES.get(kind,FILES.bold)
	var main: FontFile = load(files[0])
	var chain: Array[Font] = []
	for path in files.slice(1):
		chain.append(load(path))
	chain.append(load(SYMBOLS))
	main.fallbacks = chain
	cache[kind] = main
	return main

# Letter-spaced variant for small capitals (kickers, chips).
static func spaced(kind: String, spacing: int) -> Font:
	var key = "%s+%d" % [kind,spacing]
	if cache.has(key):
		return cache[key]
	var variation = FontVariation.new()
	variation.base_font = font(kind)
	variation.spacing_glyph = spacing
	cache[key] = variation
	return variation
