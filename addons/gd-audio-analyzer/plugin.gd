@tool
extends EditorPlugin

func _enter_tree():
	# Add custom class types when plugin is enabled
	print("GD Audio Analyzer: Enabling audio visualization toolkit...")
	
	# AudioAnalyzer - Main audio analysis component
	add_custom_type(
		"AudioAnalyzer",
		"Node",
		load("res://addons/gd-audio-analyzer/scripts/audio_analyzer.gd"),
		load("res://addons/gd-audio-analyzer/icons/audio_analyzer.svg")
	)
	
	# MultiCubeVisualizer - Visualizes audio as cube scaling
	add_custom_type(
		"MultiCubeVisualizer",
		"Node3D", 
		load("res://addons/gd-audio-analyzer/scripts/multi_cube_visualizer.gd"),
		load("res://addons/gd-audio-analyzer/icons/visualizer.svg")
	)
	
	# MultiCubeShaker - Adds shake effects to cubes
	add_custom_type(
		"MultiCubeShaker",
		"Node3D",
		load("res://addons/gd-audio-analyzer/scripts/multi_cube_shaker.gd"),
		load("res://addons/gd-audio-analyzer/icons/shaker.svg")
	)
	
	# VolumetricFogColorCycler - Cycles fog colors based on audio
	add_custom_type(
		"VolumetricFogColorCycler",
		"Node",
		load("res://addons/gd-audio-analyzer/scripts/volumetric_fog_color_cycler.gd"),
		load("res://addons/gd-audio-analyzer/icons/fog_cycler.svg")
	)
	
	# CameraShaker - Adds camera shake effects based on audio
	add_custom_type(
		"CameraShaker",
		"Node",
		load("res://addons/gd-audio-analyzer/scripts/camera_shaker.gd"),
		load("res://addons/gd-audio-analyzer/icons/camera_shaker.svg")
	)
	
	print("GD Audio Analyzer: Audio visualization components are now available in the Create Node dialog!")

func _exit_tree():
	# Remove custom class types when plugin is disabled
	print("GD Audio Analyzer: Disabling audio visualization toolkit...")
	remove_custom_type("AudioAnalyzer")
	remove_custom_type("MultiCubeVisualizer") 
	remove_custom_type("MultiCubeShaker")
	remove_custom_type("VolumetricFogColorCycler")
	remove_custom_type("CameraShaker")
	print("GD Audio Analyzer: Plugin disabled.")