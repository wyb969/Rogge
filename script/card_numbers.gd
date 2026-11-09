class_name CardNumbers
extends RefCounted

static func number(value: float, decimals: int = 2) -> String:
	var text := (("%." + str(decimals) + "f") % value)
	if text.contains("."): text = text.rstrip("0").trim_suffix(".")
	return text

static func change(label: String, before: float, after: float, unit: String = "", relative: bool = true, cost: bool = false) -> Dictionary:
	var delta := after - before
	var benefit := ""
	if not is_equal_approx(delta, 0) and before > 0 and relative:
		benefit = " " + ("+" if delta > 0 else "-") + number(absf(delta / before) * 100, 1) + "%"
	elif not is_equal_approx(delta, 0) and unit != "%":
		benefit = " " + ("+" if delta > 0 else "-") + number(absf(delta)) + unit
	var values := "%s%s → %s%s" % [number(before), unit, number(after), unit]
	if unit == "s" and before <= 0 and after > 0:
		benefit = " 启用"
		values = "未装备 → " + number(after) + unit
	var text := label + benefit + "（" + values + "）"
	var color := GamePalette.CARD_COST if cost else GamePalette.CARD_GAIN
	return {"label":label,"before":before,"after":after,"unit":unit,"cost":cost,"text":text,
		"rich":"[color=#%s]%s[b]%s[/b]（[b]%s[/b]）[/color]" % [color.to_html(false),label,benefit,values]}

static func join(rows: Array[Dictionary], rich: bool = false) -> String:
	var parts := PackedStringArray()
	for row in rows: parts.append(row.rich if rich else row.text)
	return "\n".join(parts)
