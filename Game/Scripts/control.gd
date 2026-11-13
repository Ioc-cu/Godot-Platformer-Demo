extends Control
@onready var screensize = get_window().size
@onready var camera : Node2D = $"/root/Node/Node2D".custom_camera
@onready var player : CharacterBody2D = $"/root/Node/Node2D/CharacterBody2D"
# Need to do more research on NodePaths.
#@onready var room = ^"/root/Node/Node2D:custom_camera:room"

func _ready() -> void:
	## Doesn't seem necessary any longer
	camera.room_transition.connect(func(): queue_redraw())
	pass
	
func _process(delta: float) -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if Input.is_physical_key_pressed(KEY_F3) and self.visible:
			self.hide()
		elif Input.is_physical_key_pressed(KEY_F3) and !self.visible:
			self.show()

func _draw() -> void:
	#Screen Coordinates: Screensize*room?
	#Canvas Cooridnates: get_viewport().canvas_transform.origin?
	#Tweening this will most likely be nigh impossible;
	var room : Vector2 = $"/root/Node/Node2D".custom_camera.room
	var text = "Press F3 to Show/Hide" 
	text += "\nRoom: {0}\nVelocity: {1}\nDirection: {2}\nPosition: {3}\nGridPosition: {4}\nBottomSide: {5}\nFPS: {6}\n".format(
		[room, player.velocity.round(), player.direction, player.position, 
		$"../../Node2D/TileMapLayer".local_to_map(player.position),
		$"../../Node2D/TileMapLayer".get_neighbor_cell($"../../Node2D/TileMapLayer".local_to_map(player.position),TileSet.CELL_NEIGHBOR_BOTTOM_SIDE),
		Performance.get_monitor(Performance.TIME_FPS) ])
	text += "R:{0}B:{1}L:{2}T:{3}\n".format($"../../Node2D/TileMapLayer".get_surrounding_cells($"../../Node2D/TileMapLayer".local_to_map(player.position)))
		
	#$"../../Node2D/TileMapLayer".local_to_map(player.position)
	draw_multiline_string(SystemFont.new(), Vector2(0, 20), text, HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT, -1, 8,-1,Color.RED)
