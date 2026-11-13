extends CharacterBody2D


const SPEED = 50.0
const JUMP_VELOCITY = -200.0 #Velocity starts at this value, and when it reaches >=0, character starts falling.

@onready var viewport = get_viewport()
@onready var screensize = get_window().size

@onready var anim_sprite : AnimatedSprite2D = $MouseNpc_Animated
@onready var tile_detector : Area2D = $Area2D
@onready var tilemaplayer : TileMapLayer = $"../TileMapLayer"

@onready var node2d = get_parent()

var prev = Vector2.ZERO
var counter = 0
var direction = 0
enum Direction {Left = -1, Right = 1}
var face_direction = 1
var near_ladder : bool = false

var state = State.Idle
enum State {Idle, Walk, Jump, Climb, Fall, Melee, Shoot}

var item = Item.None
enum Item {None, Melee, Magic}


func _ready() -> void:
	tile_detector.body_entered.connect(func(_body): near_ladder = true)
	tile_detector.body_exited.connect(func(_body): near_ladder = false)
	viewport.size_changed.connect(func(): self.screensize = get_window().size)



func _physics_process(delta: float) -> void:
	char_movement_fsm(delta)
	item_usage_fsm(delta)
	if direction != 0:
		face_direction = direction
	if direction == 1:
		position.x = ceil(position.x) # We have to normalize movement values, otherwise *weird* graphical glitches occcur
	elif direction == -1:
		position.x = floor(position.x)
	#position.y = (float)((int)(position.y))
	#char_animation()
	


#For using items and weapons: Implement item_usage_fsm As part of the player's CSM.
## FSM implementation for item usage. Part of the player's CSM.
func item_usage_fsm(_delta:float) -> void:
	#Have to deal with State.Melee and State.Shoot here?
	match item:
		Item.None:
			if Input.is_action_just_pressed("Primary_Attack"):
				item = Item.Melee
			elif Input.is_action_just_pressed("Projectile_Attack"):
				item = Item.Magic
		Item.Melee:
			anim_sprite.play("melee")
			item = Item.None
		Item.Magic:
			projectile()
			anim_sprite.play("shoot")
			item = Item.None


func char_movement_fsm(delta:float) -> void:
	#Current Bugs: Texture Glitching: When character is on n.5 or any floating point near it, texture glitches. Either: 1. Snap position to 0.6 or 0.4, or don't use floating points (Ended up using integers).
	#For 2 Inputs to work on pararrel: Concurrent State Machine.
	match state:
		State.Idle:
			velocity = Vector2.ZERO
			char_animation_fsm(state)
			## Climbing Transition
			if near_ladder:
				var current_cell = tilemaplayer.local_to_map(position)
				#We need to "warp" player 8 pixels down to show he's climbing a ladder
				if Input.is_action_just_pressed("move_down") and tilemaplayer.get_cell_source_id(current_cell + (Vector2i.DOWN*3)) == 1:
					position.y = tilemaplayer.map_to_local(current_cell+ Vector2i.DOWN).y - 4
					#position.y +=8
					char_animation_fsm(State.Climb)
					set_collision_mask_value(1, false)
					position.x = $"../TileMapLayer".map_to_local(current_cell).x
					state = State.Climb
				elif Input.is_action_just_pressed("move_up") and $"../TileMapLayer".get_cell_source_id(current_cell) == 1:
					set_collision_mask_value(1, false)
					position.x = $"../TileMapLayer".map_to_local(current_cell).x
					state = State.Climb


			if not is_on_floor() or !near_ladder:
				state = State.Fall
			if Input.get_axis("move_left", "move_right"):
				state = State.Walk
			elif Input.is_action_just_pressed("jump") and is_on_floor():
				state = State.Jump
			move_and_slide()
		State.Walk:
			# Get the input direction and handle the movement/deceleration.
			# As good practice, you should replace Godot's default UI input actions with custom gameplay actions.
			self.direction = Input.get_axis("move_left", "move_right")
			if direction:
				velocity.x = direction * SPEED
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
			#State.Walk -> State.Idle Transition
			if !direction:
				state = State.Idle
			elif Input.is_action_just_pressed("jump") and is_on_floor():
				state = State.Jump
			if not is_on_floor():
				velocity.x = 0
				state = State.Fall
			char_animation_fsm(state)
			move_and_slide()
		State.Jump:
			# Handle jump.
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
			# Add the gravity.
			if not is_on_floor():
				velocity += get_gravity() * delta
			if velocity.y > 0:
				state = State.Fall
			#For movement while jumping (Disabled, not currently needed in this project's scope):
			#self.direction = Input.get_axis("move_left", "move_right")
			#if direction:
				#velocity.x = direction * SPEED
			#else:
				#velocity.x = move_toward(velocity.x, 0, SPEED)
			char_animation_fsm(state)
			move_and_slide()
		State.Climb:
			var ver_direction = Input.get_axis("move_up","move_down")
			var current_cell = tilemaplayer.local_to_map(position)
			#This must be used as an exit condition. After player gets warped above ground, must instantly change to idle state(And not float above ground: needs fixing).
			if tilemaplayer.get_cell_source_id(current_cell) == -1 and ver_direction == Vector2.UP.y and !get_collision_mask_value(1) and !Input.is_action_just_pressed("move_down"):
				#8-pixel detraction can lead to bugs, re-translate: This goes 12 pixels up?
				position.y = tilemaplayer.map_to_local(current_cell+Vector2i.UP).y + 4
				#position.y -= 8
				set_collision_mask_value(1, true)
				state = State.Idle
				char_animation_fsm(state)
				#move_and_slide()
				#print(is_on_floor())
				return
			if ver_direction == 1:
				velocity.y = ver_direction * SPEED
			elif ver_direction == -1:
				velocity.y = ver_direction * SPEED
			else:
				velocity.y = move_toward(velocity.y, 0, SPEED)
			if !near_ladder or (is_on_floor() and velocity.y ==0):
				print("is_on_floor: ", is_on_floor())
				set_collision_mask_value(1, true)
				state=State.Idle
			if !velocity.y:
				anim_sprite.pause()
			else:
				char_animation_fsm(state)
			move_and_slide()
		State.Fall:
			# Add the gravity.
			if not is_on_floor():
				velocity += get_gravity() * delta
			if is_on_floor():
				state = State.Idle
			#For movement while falling:
			#self.direction = Input.get_axis("move_left", "move_right")
			#if direction:
				#velocity.x = direction * SPEED
			#else:
				#velocity.x = move_toward(velocity.x, 0, SPEED)
			char_animation_fsm(state)
			move_and_slide()

## FSM animations
func char_animation_fsm(state):
	#Direction Handling (Reverse Gravity: flip_v)
	if direction == 1: ## flip_h.true = AnimatedSprite2D.transform2D.x.x = -1. flip_v.true = AnimatedSprite2D.transform2D.y.y = -1
		anim_sprite.flip_h = false
	elif direction == -1: ## flip_h.false = AnimatedSprite2D.transform2D.x.x = -1. flip_v.true = AnimatedSprite2D.transform2D.y.y = 1
		anim_sprite.flip_h = true
	## States: Idle, Walk, Jump-Fall, Ladder, Melee, UseItem/Ranged
	match state:
		State.Idle:
			if !anim_sprite.animation == "idle":
				anim_sprite.stop()
			if !anim_sprite.is_playing():
				anim_sprite.play("idle")
		State.Walk:
			if !anim_sprite.animation == "walk":
				anim_sprite.stop()
			if !anim_sprite.is_playing():
				anim_sprite.play("walk")
		State.Jump:
			anim_sprite.play("jump")
		State.Fall:
			anim_sprite.play("fall")
		State.Climb:
			anim_sprite.play("climb")
		State.Melee:
			anim_sprite.play("melee")
		State.Shoot:
			anim_sprite.play("shoot")

## A Custom Projectile
func projectile():
	var bullet : Area2D = load("res://Game/Scenes/bullet.tscn").instantiate()
	bullet.position = self.position
	bullet.position.x = self.position.x + 10 * face_direction
	bullet.direction = face_direction
	get_parent().add_child(bullet)


## Deprecated Corner

## @deprecated Old Ad-Hoc Movement.
func char_movement(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	self.direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	#position.clamp(Vector2(0,0), (Vector2) (screensize))

## @deprecated Could use input parameter: State, and instead of passing it on loop, we pass it to char control. Deprecated for FSM (Most likely to be succeeded by CSM)
func char_animation():
	#Direction Handling (Reverse Gravity: flip_v)
	if direction == 1: ## flip_h.true = AnimatedSprite2D.transform2D.x.x = -1. flip_v.true = AnimatedSprite2D.transform2D.y.y = -1
		anim_sprite.flip_h = false
	elif direction == -1: ## flip_h.false = AnimatedSprite2D.transform2D.x.x = -1. flip_v.true = AnimatedSprite2D.transform2D.y.y = 1
		anim_sprite.flip_h = true
	#Walking
	if direction:
		anim_sprite.play("walk")
	else:
		anim_sprite.stop()
	#Jumping/Falling
	if velocity.y < 0:
		anim_sprite.play("jump")
	elif velocity.y >  0:
		anim_sprite.play("fall")
	else:
		anim_sprite.play("walk")
	pass

## @deprecated: Cannot turn TileSet's PhysicsLayers into Area2D detectors(yet)
func detect_ladder() -> int:
	var tilemap_layer:TileMapLayer = $"../TileMapLayer"
	var source_id = tilemap_layer.get_cell_source_id(
		Vector2(position.x/tilemap_layer.tile_set.tile_size.x, position.y/tilemap_layer.tile_set.tile_size.y).round() )
	return source_id

func ladder_warping():
	
	pass
