# GD Audio Analyzer

Real-time audio analysis toolkit for Godot 4.5+.

![GD Audio Analyzer Demo](example.mp4)

## Features

- Real-time FFT audio analysis with frequency bands
- Beat detection with configurable sensitivity
- Audio intensity analysis and smoothing
- Signal-based event system

## Quick Start

1. Extract to `addons/` folder
2. Enable in Project Settings > Plugins
3. Add `AudioStreamPlayer` and `AudioAnalyzer` nodes
4. Connect audio player to analyzer

```gdscript
@onready var audio_analyzer = $AudioAnalyzer
func _ready():
    audio_analyzer.audio_player = $AudioStreamPlayer
    audio_analyzer.beat_detected.connect(_on_beat_detected)
    audio_analyzer.frequency_band_changed.connect(_on_frequency_changed)

func _on_beat_detected(intensity: float):
    print("Beat detected with intensity: ", intensity)

func _on_frequency_changed(band_index: int, intensity: float):
    print("Band ", band_index, " intensity: ", intensity)
```

## Use Cases

### Music Visualizers

- Create audio-reactive visual effects that respond to different frequency ranges
- Build spectrum analyzers with real-time frequency band data
- Sync visual elements to beat detection for rhythm games

### Game Audio Integration

- Trigger particle effects or screen shake on bass drops
- Adjust lighting intensity based on audio energy
- Create dynamic environments that react to background music

### Interactive Applications

- Voice-controlled interfaces using frequency analysis
- Audio-reactive user interfaces and menus
- Real-time audio feedback for music production tools

### Creative Projects

- Procedural art generation based on audio input
- Audio-synchronized animations and transitions
- Interactive installations responding to ambient sound

## AudioAnalyzer

Core component that analyzes audio streams and emits signals for visualization.

**Key Properties:**

- `audio_player`: AudioStreamPlayer to analyze
- `num_bands`: Number of frequency bands (1-64)
- `sensitivity`: Beat detection sensitivity
- `beat_threshold`: Threshold for beat detection

**Signals:**

- `frequency_band_changed(band_index: int, intensity: float)`
- `beat_detected(overall_intensity: float)`
- `shake_triggered(shake_intensity: float)`

## License

MIT License - see [LICENSE](LICENSE) file.