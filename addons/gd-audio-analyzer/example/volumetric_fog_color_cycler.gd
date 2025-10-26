extends Node
# Volumetric Fog Color Cycler
# Cycles the volumetric fog color through a spectrum like breathing lights
# Attach this to any node in the scene

@export var world_environment: WorldEnvironment
@export var audio_analyzer: AudioAnalyzer
@export var cycle_speed: float = 0.3  # How fast to cycle through colors (lower = slower)
@export var saturation: float = 0.8  # Color saturation (0.0 to 1.0)
@export var value: float = 0.6  # Color brightness (0.0 to 1.0)
@export var base_density: float = 0.01  # Base fog density
@export var auto_find_environment: bool = true  # Automatically find WorldEnvironment in scene

# Flash effect settings
@export_group("Flash Effect")
@export var enable_flash: bool = true  # Enable flash effect on beats
@export var flash_intensity: float = 2.5  # How bright the flash is (multiplier)
@export var flash_duration: float = 0.15  # How long the flash lasts (seconds)
@export var flash_fade_speed: float = 8.0  # How fast the flash fades out

var time_accumulator: float = 0.0
var fog_material: FogMaterial
var flash_amount: float = 0.0  # Current flash brightness (0 to 1)
var is_flashing: bool = false

func _ready():
	# Try to find WorldEnvironment if not assigned
	if auto_find_environment and world_environment == null:
		world_environment = get_tree().get_first_node_in_group("world_environment")
		
		if world_environment == null:
			# Search for WorldEnvironment in the scene tree
			world_environment = find_world_environment(get_tree().root)
	
	if world_environment == null:
		push_error("WorldEnvironment not found! Please assign it in the inspector or add WorldEnvironment to 'world_environment' group.")
		return
	
	setup_volumetric_fog()
	connect_to_audio_analyzer()

func connect_to_audio_analyzer():
	if audio_analyzer == null:
		push_warning("AudioAnalyzer not assigned. Flash effects will not work.")
		return
	
	# Connect to beat signal for flash effects
	if not audio_analyzer.beat_detected.is_connected(_on_beat_detected):
		audio_analyzer.beat_detected.connect(_on_beat_detected)

func find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	
	for child in node.get_children():
		var result = find_world_environment(child)
		if result != null:
			return result
	
	return null

func setup_volumetric_fog():
	# Get or create environment
	if world_environment.environment == null:
		world_environment.environment = Environment.new()
	
	var env = world_environment.environment
	
	# Enable volumetric fog if not already enabled
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = base_density
	
	# Set initial fog color
	env.volumetric_fog_albedo = Color.from_hsv(0.0, saturation, value)
	

func _process(delta: float):
	if world_environment == null or world_environment.environment == null:
		return
	
	# Accumulate time for color cycling
	time_accumulator += delta * cycle_speed
	
	# Keep time in range [0, 1] by wrapping around
	if time_accumulator > 1.0:
		time_accumulator -= 1.0
	
	# Calculate hue from time (0 to 1 maps to full color spectrum)
	var hue = time_accumulator
	
	# Create base color from HSV
	var base_color = Color.from_hsv(hue, saturation, value)
	
	# Apply flash effect if active
	if flash_amount > 0.0:
		# Fade out the flash
		flash_amount = max(0.0, flash_amount - delta * flash_fade_speed)
		
		# Brighten the color based on flash amount
		var flash_multiplier = 1.0 + (flash_intensity * flash_amount)
		var final_color = base_color * flash_multiplier
		world_environment.environment.volumetric_fog_albedo = final_color
	else:
		# No flash, use base color
		world_environment.environment.volumetric_fog_albedo = base_color

func _on_beat_detected(overall_intensity: float):
	if not enable_flash:
		return
	
	# Trigger flash effect (normalized intensity from 1-15 range)
	var normalized_intensity = (overall_intensity - 1.0) / 14.0
	flash_amount = clamp(normalized_intensity, 0.3, 1.0)  # Minimum 30% flash
	is_flashing = true
	