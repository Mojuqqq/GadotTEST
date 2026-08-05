extends Node2D


@onready var burst: GPUParticles2D = (
	$Burst
)

@onready var rising: GPUParticles2D = (
	$Rising
)


func _ready() -> void:
	burst.restart()
	rising.restart()

	# Rising живёт дольше, поэтому ждём
	# завершения именно этой системы.
	await rising.finished

	queue_free()
