extends Node
class_name AudioAnalyzer

# Signals for each frequency band (0 to num_bands-1, where 0 is lowest frequency)
signal frequency_band_changed(band_index: int, intensity: float)
signal beat_detected(overall_intensity: float)
signal shake_triggered(shake_intensity: float)

# Configuration
@export var audio_player: Node  # Supports AudioStreamPlayer, AudioStreamPlayer2D, or AudioStreamPlayer3D
@export_range(1, 64) var num_bands: int = 10  # Number of frequency bands
@export_enum("256:5", "512:6", "1024:7", "2048:8", "4096:9", "8192:10") var fft_size_enum: int = 8  # FFT size for spectrum analysis
@export var update_frequency: float = 120.0  # Updates per second (increased for more responsiveness)
@export var sensitivity: float = 3.0  # Beat detection sensitivity (increased)
@export var smoothing: float = 0.1  # Smoothing factor for intensity changes (reduced for more bounce)
@export var min_scale: float = 1.0  # Minimum scale value
@export var max_scale: float = 15.0  # Maximum scale value (increased for more dramatic effect)
@export var intensity_multiplier: float = 2.5  # Multiplier for overall intensity (new)
@export var beat_threshold: float = 0.05  # Lower threshold for beat detection (more sensitive)
@export var shake_threshold: float = 0.08  # Threshold for shake detection (lowered for more shakes)
@export var shake_cooldown: float = 0.15  # Minimum time between shake events (seconds)

# Frequency band ranges - will be generated dynamically based on num_bands
var frequency_bands: Array[Array] = []

# Internal variables
var spectrum_analyzer: AudioEffectSpectrumAnalyzer
var effect_instance: AudioEffectSpectrumAnalyzerInstance
var previous_intensities: Array[float] = []
var smoothed_intensities: Array[float] = []
var update_timer: float = 0.0
var sample_rate: float = 44100.0
var fft_size: int = 2048  # Will be set based on fft_size_enum
var last_shake_time: float = 0.0  # Track time of last shake event (in milliseconds)

func generate_frequency_bands():
	"""Generate frequency bands dynamically based on num_bands"""
	frequency_bands.clear()
	
	# Frequency range from 20Hz to 20kHz (human hearing range)
	var min_freq = 20.0
	var max_freq = 20000.0
	
	if num_bands == 1:
		# Single band covers entire spectrum
		frequency_bands.append([min_freq, max_freq])
	else:
		# Use logarithmic distribution for better musical perception
		# This gives more resolution to lower frequencies where musical content is concentrated
		var log_min = log(min_freq)
		var log_max = log(max_freq)
		var log_step = (log_max - log_min) / num_bands
		
		for i in range(num_bands):
			var band_log_min = log_min + i * log_step
			var band_log_max = log_min + (i + 1) * log_step
			
			var band_min = exp(band_log_min)
			var band_max = exp(band_log_max)
			
			frequency_bands.append([band_min, band_max])

func _ready():
	# Set FFT size based on enum selection
	match fft_size_enum:
		5: fft_size = 256
		6: fft_size = 512
		7: fft_size = 1024
		8: fft_size = 2048
		9: fft_size = 4096
		10: fft_size = 8192
		_: fft_size = 2048
	
	# Generate frequency bands dynamically
	generate_frequency_bands()
	
	# Initialize arrays
	previous_intensities.resize(num_bands)
	smoothed_intensities.resize(num_bands)
	for i in range(num_bands):
		previous_intensities[i] = 0.0
		smoothed_intensities[i] = 0.0
	
	# Set up audio analysis
	setup_audio_analysis()

func setup_audio_analysis():
	if not audio_player:
		return
	
	# Validate that the assigned node is an audio player
	if not (audio_player is AudioStreamPlayer or audio_player is AudioStreamPlayer2D or audio_player is AudioStreamPlayer3D):
		return
	
	# Create spectrum analyzer effect
	spectrum_analyzer = AudioEffectSpectrumAnalyzer.new()
	spectrum_analyzer.buffer_length = 2.0  # 2 second buffer for better frequency resolution
	
	# Set FFT size based on configuration
	match fft_size:
		256: spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_256
		512: spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
		1024: spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		2048: spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		4096: spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_4096
		_: spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
	
	# Add the effect to the audio player's bus
	var bus_index = AudioServer.get_bus_index(audio_player.bus)
	AudioServer.add_bus_effect(bus_index, spectrum_analyzer)
	
	# Get the effect instance
	effect_instance = AudioServer.get_bus_effect_instance(bus_index, AudioServer.get_bus_effect_count(bus_index) - 1)

func _process(delta):
	if not effect_instance:
		return
	
	update_timer += delta
	if update_timer >= 1.0 / update_frequency:
		update_timer = 0.0
		analyze_audio()

func analyze_audio():
	if not effect_instance:
		return
	
	var current_intensities: Array[float] = []
	current_intensities.resize(num_bands)
	
	# Analyze each frequency band
	for band_index in range(num_bands):
		var intensity = get_frequency_band_intensity(band_index)
		current_intensities[band_index] = intensity
		
		# Apply smoothing
		smoothed_intensities[band_index] = lerp(smoothed_intensities[band_index], intensity, smoothing)
		
		# Convert to scale value (1-10)
		var scale_value = remap(smoothed_intensities[band_index], 0.0, 1.0, min_scale, max_scale)
		scale_value = clampf(scale_value, min_scale, max_scale)
		
		# Emit signal for this frequency band
		frequency_band_changed.emit(band_index, scale_value)
	
	# Beat detection - check for sudden increases in overall intensity
	var overall_intensity = 0.0
	for intensity in current_intensities:
		overall_intensity += intensity
	overall_intensity /= num_bands
	
	# Simple beat detection: compare current intensity with recent average
	var intensity_increase = overall_intensity - get_average_intensity()
	if intensity_increase > beat_threshold:  # Use configurable threshold for beat detection
		var beat_strength = remap(intensity_increase, 0.0, 1.0, min_scale, max_scale)
		beat_detected.emit(clampf(beat_strength, min_scale, max_scale))
	
	# Shake detection: triggered by very intense beats or sustained high intensity
	var current_time_ms = Time.get_ticks_msec()
	var elapsed_since_last_shake = (current_time_ms - last_shake_time) / 1000.0
	
	if elapsed_since_last_shake >= shake_cooldown:
		# Check for shake conditions: very intense beat or sustained high intensity
		var should_shake = false
		var shake_strength = 0.0
		
		# Condition 1: Very intense beat (stronger than regular beat threshold)
		if intensity_increase > shake_threshold:
			should_shake = true
			shake_strength = remap(intensity_increase, shake_threshold, 1.0, min_scale, max_scale)
		
		# Condition 2: Sustained high intensity across multiple bands
		var high_intensity_bands = 0
		for intensity in current_intensities:
			if intensity > 0.4:  # 40% of max intensity (lowered from 60%)
				high_intensity_bands += 1
		
		if high_intensity_bands >= num_bands * 0.5:  # 50% of bands are high intensity (lowered from 70%)
			should_shake = true
			shake_strength = max(shake_strength, remap(float(high_intensity_bands) / num_bands, 0.5, 1.0, min_scale, max_scale))
		
		if should_shake:
			shake_strength = clampf(shake_strength, min_scale, max_scale)
			shake_triggered.emit(shake_strength)
			last_shake_time = current_time_ms
	previous_intensities = current_intensities.duplicate()

func get_frequency_band_intensity(band_index: int) -> float:
	if band_index < 0 or band_index >= frequency_bands.size():
		return 0.0
	
	var band_range = frequency_bands[band_index]
	var min_freq = band_range[0]
	var max_freq = band_range[1]
	
	# Convert frequency to spectrum bins
	var min_bin = freq_to_bin(min_freq)
	var max_bin = freq_to_bin(max_freq)
	
	var intensity = 0.0
	var bin_count = 0
	
	# Sum up the magnitude in this frequency range
	for bin in range(min_bin, max_bin + 1):
		var magnitude = effect_instance.get_magnitude_for_frequency_range(
			bin_to_freq(bin), 
			bin_to_freq(bin + 1)
		)
		intensity += magnitude.length()
		bin_count += 1
	
	if bin_count > 0:
		intensity /= bin_count
	
	# Apply logarithmic scaling for better visualization
	intensity = sqrt(intensity) * sensitivity * intensity_multiplier
	
	return clampf(intensity, 0.0, 1.0)

func freq_to_bin(frequency: float) -> int:
	var nyquist = sample_rate / 2.0
	var usable_bins = float(fft_size) / 2.0  # Half of FFT size gives usable frequency bins
	var bin_size = nyquist / usable_bins
	return int(frequency / bin_size)

func bin_to_freq(bin: int) -> float:
	var nyquist = sample_rate / 2.0
	var usable_bins = float(fft_size) / 2.0
	var bin_size = nyquist / usable_bins
	return bin * bin_size

func get_average_intensity() -> float:
	if previous_intensities.is_empty():
		return 0.0
	
	var total = 0.0
	for intensity in previous_intensities:
		total += intensity
	return total / previous_intensities.size()

# Helper function to connect an AudioStreamPlayer (supports AudioStreamPlayer, AudioStreamPlayer2D, AudioStreamPlayer3D)
func connect_audio_player(player: Node):
	if player is AudioStreamPlayer or player is AudioStreamPlayer2D or player is AudioStreamPlayer3D:
		audio_player = player
		setup_audio_analysis()

# Helper function to get intensity for a specific band (for external use)
func get_band_intensity(band_index: int) -> float:
	if band_index >= 0 and band_index < smoothed_intensities.size():
		return remap(smoothed_intensities[band_index], 0.0, 1.0, min_scale, max_scale)
	return min_scale

# Helper function to connect shake events to a target node
func connect_shake_to_node(target_node: Node, method_name: String):
	if not shake_triggered.is_connected(Callable(target_node, method_name)):
		shake_triggered.connect(Callable(target_node, method_name))

# Update configuration at runtime
func set_num_bands(new_num_bands: int):
	num_bands = clamp(new_num_bands, 1, 64)
	generate_frequency_bands()
	
	# Resize arrays
	previous_intensities.resize(num_bands)
	smoothed_intensities.resize(num_bands)
	
	# Initialize new elements if array grew
	for i in range(previous_intensities.size()):
		if i >= previous_intensities.size() or previous_intensities[i] == null:
			previous_intensities[i] = 0.0
		if i >= smoothed_intensities.size() or smoothed_intensities[i] == null:
			smoothed_intensities[i] = 0.0

func set_fft_size_by_enum(new_fft_enum: int):
	fft_size_enum = new_fft_enum
	match fft_size_enum:
		5: fft_size = 256
		6: fft_size = 512
		7: fft_size = 1024
		8: fft_size = 2048
		9: fft_size = 4096
		10: fft_size = 8192
		_: fft_size = 2048
	
	# Restart audio analysis with new FFT size
	if audio_player:
		setup_audio_analysis()
