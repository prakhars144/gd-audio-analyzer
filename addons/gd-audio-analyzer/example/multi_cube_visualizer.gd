extends Node3D
# Multi-cube audio visualizer setup script
# Attach this to a parent node that contains cube children

@export var audio_analyzer: AudioAnalyzer
@export var assign_colors: bool = true  # Whether to assign rainbow colors to cubes
@export var animation_speed: float = 15.0  # How fast cubes animate (increased for snappier response)
@export var min_scale: float = 0.1  # Minimum Y scale (very small when no audio)
@export var max_scale: float = 8.0  # Maximum Y scale multiplier (much taller)
@export var scale_power: float = 2.0  # Power curve for more dramatic scaling
@export var beat_boost_multiplier: float = 1.5  # Extra boost on beats

# Internal variables
var cubes: Array[MeshInstance3D] = []
var target_scales: Array[float] = []
var base_scales: Array[Vector3] = []  # Store original scales

func _ready():
	setup_existing_cubes()
	connect_to_audio_analyzer()

func setup_existing_cubes():
	# Get all child nodes that are MeshInstance3D (cubes)
	cubes.clear()
	for child in get_children():
		if child is MeshInstance3D:
			cubes.append(child)
	
	if cubes.is_empty():
		return
	
	# Initialize target scales and store base scales
	target_scales.resize(cubes.size())
	base_scales.resize(cubes.size())
	for i in range(cubes.size()):
		target_scales[i] = min_scale  # Start at minimum scale
		base_scales[i] = cubes[i].scale  # Store original scale
		cubes[i].scale.y = min_scale  # Set initial Y scale to minimum
		
	# Set up colors for each cube
	for i in range(cubes.size()):
		var cube = cubes[i]
		
		# Optional: Assign rainbow colors for visual distinction
		if assign_colors:
			var hue = float(i) / float(cubes.size())
			set_cube_material_color(cube, Color.from_hsv(hue, 0.8, 1.0))
		
func connect_to_audio_analyzer():
	if not audio_analyzer:
		return
	
	# Connect to audio analyzer signals
	audio_analyzer.frequency_band_changed.connect(_on_frequency_band_changed)
	audio_analyzer.beat_detected.connect(_on_beat_detected)

func _process(delta: float):
	# Animate all cubes to their target scales with bouncy effect
	for i in range(cubes.size()):
		if i < target_scales.size():
			var current_scale = cubes[i].scale.y
			var target_scale = target_scales[i]
			
			# Use exponential smoothing for snappier response
			var new_scale = lerp(current_scale, target_scale, animation_speed * delta)
			
			# Apply the scale, maintaining original X and Z
			cubes[i].scale = Vector3(
				base_scales[i].x,
				new_scale,
				base_scales[i].z
			)

func _on_frequency_band_changed(band_index: int, intensity: float):
	# Update target scale for the corresponding cube
	if band_index < cubes.size() and band_index < target_scales.size():
		# Convert intensity (1-10) to dramatic scale range
		var normalized_intensity = (intensity - 1.0) / 9.0  # Convert to 0-1 range
		
		# Apply power curve for more dramatic effect
		normalized_intensity = pow(normalized_intensity, 1.0 / scale_power)
		
		# Map to scale range (min_scale to max_scale)
		var scale_value = min_scale + (normalized_intensity * (max_scale - min_scale))
		
		target_scales[band_index] = scale_value

func _on_beat_detected(overall_intensity: float):
	# Boost all cubes temporarily on beat detection
	for i in range(target_scales.size()):
		var current_target = target_scales[i]
		var beat_intensity = (overall_intensity - 1.0) / 9.0  # Normalize beat intensity
		var boosted_scale = current_target * (1.0 + beat_intensity * beat_boost_multiplier)
		target_scales[i] = min(boosted_scale, max_scale)  # Cap at max scale

# Helper function to set cube color
func set_cube_material_color(cube_node: MeshInstance3D, color: Color):
	if cube_node.material_override:
		cube_node.material_override.albedo_color = color
	else:
		var new_material = StandardMaterial3D.new()
		new_material.albedo_color = color
		cube_node.material_override = new_material
