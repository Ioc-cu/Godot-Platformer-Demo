class_name Level extends Node2D
## Prints Debugging Information on-screen when you press a hotkey (F9 for example)
## Mabye move the camera here...?
## Inherit Screen resolution from settings ()

@onready var canvas_transform = get_viewport().canvas_transform.origin
@onready var custom_camera = CustomCamera.new()

@onready var viewport_dimensions : Vector2i  = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), 
	ProjectSettings.get_setting("display/window/size/viewport_height"))


## The property Viewport.canvas_transform can only be grabbed at runtime?

func _ready() -> void:
	custom_camera.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	custom_camera.name = "CustomCamera"
	add_child(custom_camera, true)

func _physics_process(_delta: float) -> void:
	custom_camera.custom_camera()

#Way to make camera animate:
#1. Instead of instantly changing the origin of canvas_transform, tween it. Done.
#2. Detect when player('s collision shape) is going through screen edges. Camera2D's drag_bottom_margin seems interesting. Done.
#viewport.global_canvas_transform.origin = self.position
#Move camera smoothly: an animation that disables movement until it's finished? (but doesn't disable velocity!)
# Also slightly move the player towards the edge of the screen, opposite of the player (where he happens to appear on the next screen anyway due to screen transition) in order to fit perfectly pixel-wise [TBI]

## The Purpose of this custom camera is to implement room-like camera transitions, instead of following the player.
##
## Of cource, this functionality can be implemented in a function no problem, so what's the purpose of this class?
## Because this camera implementation is custom (it does not use Camera2D), it must be of type Node, in order to set it's process mode to PROCESS_MODE_WHILE_PAUSED, so it can transition to the next room even if the whole game's paused.
##
## With that said, the camera code should be within the Level Node's Script; Otherwise, it's CanvasItem elements will move along with the player, something that is unwanted.
## After all, Stretching the window shouldn't affect that functionality.
# Issues: ParallaxBody: When moving forward, parallax orientation doesn't stay consistent (it moves in the front, and when it moves back, it gets weird) Fixed?
# Camera Bug: Sometimes, it uses a different transform parameter (i.e. native res) to move the camera, moving multiple rooms. Consider using project setting's initial res? 

class CustomCamera extends Node2D:
	signal room_transition
	## used for custom_camera function
	@onready var Character = $"/root/Node/Node2D/CharacterBody2D"
	@onready var screensize = $"..".viewport_dimensions
	@onready var viewport = get_viewport()
	@onready var parallax_2d: Parallax2D = $"../Parallax2D"
	var prev : Vector2 = Vector2.ZERO
	var room : Vector2 = Vector2.ZERO
	
	func _ready() -> void:
		#We NEED tween.finished.connect() somehow to work if we want to pause and unpause the game, however using play() and stop() causes some bizzare recursive behavior with the animations. Investigate
		## Resizing Window whenever screensize changes (Might be unnecessary with ProjectSettings.display/window/stretch/mode = "viewport" Setting)
		## Change this to take viewport_dimesions instead, since screen stretch shouldn't affect base viewport.
		#get_viewport().size_changed.connect(func(): self.screensize = get_window().size)
		pass

	## Physics Process checks for custom camera's movement every frame? Could potentially use improvements
	func _physics_process(_delta: float) -> void:
		custom_camera()

	## The function responsible for camera movement, animation, pausing/unpausing the SceneTree and spawning enemies, basically every functionality camera-related.
	## To-Fix: Diagonal Room Movement bugs the camera out. Sometimes, when run F5 with max resolution at _ready(), 
	func custom_camera():
		#Custom Camera 1.0 (By modifying viewport's canvas_transform)
		#Logic: Divide Player Position by Screensize. 
		#Resulting integer(i.e. 0,100) is the room the player is in (Only Round-ups and Round-downs are weird; Currently using Casting, but there might be a better method allowed)
		#Window.size is in fact a Vector2i vector, so it needs casting. Floor() and Ceiling() do not, in fact, give desirable results, we need the number whether it's a positive or negative number
		room = Character.position/(Vector2) (screensize)
		room.x = (int)(room.x) if room.x > 0 else (int)(room.x-1) #Making sure -0 doesn't exist, otherwise camera won't properly move on the first leftmost-screen from center
		room.y = (int)(room.y) if room.y > 0 else (int)(room.y-1) #For both x and y seperately, doing this condition on a Vector2 does NOT give intended results.
		
		#This condition handles the transition between rooms(camera movement, camera animation, pausing/unpausing the SceneTree and spawning enemies??)
		if (Vector2i)(room) != (Vector2i)(prev):
			## Emit a signal here, in order to update drawcalls
			room_transition.emit()
			## The logic behind the engine's Canvas Transforms: https://docs.godotengine.org/en/stable/tutorials/2d/2d_transforms.html#transform-functions
			## Additonally, Vector2 cast is happening because canvas_transform is of type Vector2, and Vector2i Cast  because we want integer room coordinates.
			var next = (Vector2) (screensize*(Vector2i)(room))*-1 #The Vector2 Coordinates of the next room (can just add a - instead of *-1...)
			tween_camera(next)
			queue_redraw()
			prev = room

	## Animation Segment of Camera Movement
	## Tweening the viewport.canvas_transport.origin property to animate the movement of the camera.
	func tween_camera(next: Vector2):
		var tween = create_tween()
		tween.finished.connect(func(): get_tree().paused = false) #Unpausing the scene tree when the tweening is finished
		tween.tween_property(viewport, "canvas_transform:origin", next, 1.2)
		tween.parallel() #Runs another property in pararell to above
		tween.tween_property(parallax_2d, "scroll_offset:x", next.x/10, 1.2) #Makes the parallax2D background move the opposite direction of the camera's movement
		get_tree().paused = true #And pausing the scene tree when the animation begins

func normal_camera(): ## Using Camera2D normally 
	var camera = Camera2D.new()
	self.add_child(camera)
