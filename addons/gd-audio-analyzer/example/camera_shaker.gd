extends Node
class_name CameraShaker

# Camera shake script for audio-reactive camera effects
# Attach this to a Camera3D node or as a child of a Camera3D node

@export var audio_analyzer: AudioAnalyzer
@export var camera_target: Camera3D  # Target camera to shake (if not parent)
@export var shake_intensity_multiplier: float = 1.0  # How intense the shake effect is
@export var shake_duration: float = 0.3  # How long each shake lasts (seconds)
@export var shake_return_speed: float = 0.2  # How fast camera returns to original position
@export var position_shake_range: float = 0.1  # Maximum position offset during shake
@export var rotation_shake_range: float = 2.0  # Maximum rotation offset during shake (degrees)
@export var beat_response_multiplier: float = 1.5  # Extra intensity for beat-triggered shakes
@export var enable_position_shake: bool = true  # Enable position-based shaking
@export var enable_rotation_shake: bool = true  # Enable rotation-based shaking
@export var shake_frequency: float = 25.0  # Frequency of shake oscillation

# Internal variables
var target_camera: Camera3D
var original_position: Vector3
var original_rotation: Vector3
var is_shaking: bool = false
var shake_time: float = 0.0
var shake_total_duration: float = 0.0
var shake_strength: float = 0.0
var shake_offset: Vector3 = Vector3.ZERO  # Random offset for shake pattern

func _ready():
	setup_camera()
	connect_to_audio_analyzer()

func setup_camera():
	# Find the target camera
	if camera_target:
		target_camera = camera_target
	elif get_parent() is Camera3D:
		target_camera = get_parent() as Camera3D
	
	# Store original transforms
	original_position = target_camera.position
	original_rotation = target_camera.rotation_degrees
	

func connect_to_audio_analyzer():
	if not audio_analyzer:
		return
	
	# Connect to both shake and beat signals
	if not audio_analyzer.shake_triggered.is_connected(_on_shake_triggered):
		audio_analyzer.shake_triggered.connect(_on_shake_triggered)
	if not audio_analyzer.beat_detected.is_connected(_on_beat_detected):
		audio_analyzer.beat_detected.connect(_on_beat_detected)
	
func _process(delta: float):
	if not target_camera or not is_shaking:
		return
	
	shake_time += delta
	
	# Calculate shake progress (0.0 to 1.0)
	var progress = shake_time / shake_total_duration
	
	if progress >= 1.0:
		# Shake finished, return camera to original position
		target_camera.position = original_position
		target_camera.rotation_degrees = original_rotation
		is_shaking = false
		return
	
	# Apply decay envelope (starts strong, fades to zero)
	var envelope = 1.0 - ease(progress, 0.5)  # Exponential decay
	
	# Calculate shake effects
	var time_factor = shake_time * shake_frequency
	
	if enable_position_shake:
		# Position shake using sine waves with random offset
		var shake_x = sin(time_factor + shake_offset.x) * position_shake_range * shake_strength * envelope
		var shake_y = sin(time_factor * 1.3 + shake_offset.y) * position_shake_range * shake_strength * envelope
		var shake_z = sin(time_factor * 0.7 + shake_offset.z) * position_shake_range * shake_strength * envelope
		
		var pos_offset = Vector3(shake_x, shake_y, shake_z)
		target_camera.position = original_position + pos_offset
	
	if enable_rotation_shake:
		# Rotation shake using sine waves with random offset
		var rot_x = sin(time_factor + shake_offset.x) * rotation_shake_range * shake_strength * envelope
		var rot_y = sin(time_factor * 1.7 + shake_offset.y) * rotation_shake_range * shake_strength * envelope
		var rot_z = sin(time_factor * 0.9 + shake_offset.z) * rotation_shake_range * shake_strength * envelope
		
		var rot_offset = Vector3(rot_x, rot_y, rot_z)
		target_camera.rotation_degrees = original_rotation + rot_offset

func _on_beat_detected(overall_intensity: float):
	# Trigger lighter shake effect on beats
	var normalized_intensity = (overall_intensity - 1.0) / 14.0  # Normalize from 1-15 range to 0-1
	var beat_strength = normalized_intensity * shake_intensity_multiplier * 0.5  # Lighter than main shake
	
	trigger_shake_effect(beat_strength, shake_duration * 0.6)  # Shorter duration for beats

func _on_shake_triggered(shake_intensity: float):
	# Trigger main shake effect with full intensity
	var normalized_intensity = (shake_intensity - 1.0) / 14.0  # Normalize from 1-15 range to 0-1
	var final_strength = normalized_intensity * shake_intensity_multiplier * beat_response_multiplier
	
	trigger_shake_effect(final_strength, shake_duration)

func trigger_shake_effect(strength: float, duration: float):
	if not target_camera:
		return
		
	# Set shake parameters
	shake_strength = strength
	shake_total_duration = duration
	shake_time = 0.0
	is_shaking = true
	
	# Generate new random offset for varied shake patterns
	shake_offset = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)

# Helper function to manually trigger shake (for testing)
func trigger_test_shake(intensity: float = 5.0):
	trigger_shake_effect(intensity * shake_intensity_multiplier, shake_duration)

# Helper function to reset camera to original position
func reset_camera():
	if not target_camera:
		return
	
	is_shaking = false
	shake_time = 0.0
	target_camera.position = original_position
	target_camera.rotation_degrees = original_rotation

# Helper function to update original position/rotation (call when camera moves)
func update_original_transform():
	if not target_camera:
		return
	
	if not is_shaking:  # Only update if not currently shaking
		original_position = target_camera.position
		original_rotation = target_camera.rotation_degrees

# Helper function to set new camera target
func set_camera_target(new_camera: Camera3D):
	if new_camera:
		camera_target = new_camera
		setup_camera()

# Configure shake settings at runtime
func set_shake_intensity(new_intensity: float):
	shake_intensity_multiplier = new_intensity

func set_shake_duration(new_duration: float):
	shake_duration = new_duration

func set_position_shake_range(new_range: float):
	position_shake_range = new_range

func set_rotation_shake_range(new_range: float):
	rotation_shake_range = new_range