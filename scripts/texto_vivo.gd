extends Node
## Recalcula textos formateados al cambiar de idioma, sin reconstruir la
## pantalla ni repetir compras, premios o animaciones.
var calcular: Callable

func _ready() -> void:
	actualizar()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		actualizar.call_deferred()

func actualizar() -> void:
	if calcular.is_valid() and not get_parent().is_queued_for_deletion():
		get_parent().text = calcular.call()
