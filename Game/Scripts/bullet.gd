extends Area2D
var direction = 0
const SPEED = 300 
@onready var prev = 0.0
@onready var anim : AnimatedSprite2D = $AnimatedSprite2D
@onready var notifier : VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
var state = State.Default
enum State {Default, Collision}

#If projectile is out of the screen, despawn.
func _ready() -> void:
	#Object freeing, very crude and basic, needs work (got that covered with fsm)
	body_entered.connect(func(body): if body != $".": state = State.Collision)
	notifier.screen_exited.connect(func(): queue_free())

func _physics_process(delta: float) -> void:
	projectile_fsm()
	pass

func projectile_fsm():
	match state:
		State.Default:
			#Clearly, we need to get the player's previous (aka current) direction?
			position.x += direction
			prev = direction
			if direction == 1: ## flip_h.true = AnimatedSprite2D.transform2D.x.x = -1. flip_v.true = AnimatedSprite2D.transform2D.y.y = -1
				anim.flip_h = false
			elif direction == -1: ## flip_h.false = AnimatedSprite2D.transform2D.x.x = -1. flip_v.true = AnimatedSprite2D.transform2D.y.y = 1
				anim.flip_h = true
			anim.play("default")
		State.Collision:
			if !anim.is_playing():
				queue_free()
			anim.play("collision")
