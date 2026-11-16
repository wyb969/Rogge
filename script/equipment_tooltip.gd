extends Panel

func _make_custom_tooltip(for_text: String) -> Object:
	return L10n.tooltip(for_text, self)
