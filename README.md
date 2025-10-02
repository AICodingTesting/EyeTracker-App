# EyeTracker Suite

EyeTracker Suite is a Swift Package-based workspace that showcases an on-device gaze tracking pipeline with reusable components for iOS and macOS prototypes. It includes:

- **GazeTrackingKit**: capture providers, calibration logic, smoothing filters, heatmap/trail renderers, and session coordination.
- **GazeUI**: cross-platform SwiftUI views for live gaze visualization, calibration, metrics, and exports.
- **GazeLabPreviewer**: a lightweight SwiftUI app target demonstrating the dashboard in action.

> **Privacy-first design** – all processing runs locally. No network connections are performed and the default camera providers only operate while the previewer is in the foreground.

## Repository layout

```
.
├── Package.swift
├── README.md
├── Sources
│   ├── GazeLabPreviewer        # SwiftUI demo app entry point
│   ├── GazeTrackingKit         # Core gaze tracking pipeline
│   └── GazeUI                  # SwiftUI components
└── Tests
    ├── GazeTrackingKitTests
    └── GazeUITests
```

## Getting started

1. Install the latest Xcode (15.1+) on macOS 14.
2. Open the package in Xcode:
   ```bash
   open Package.swift
   ```
3. Select the **GazeLabPreviewer** scheme and run on either the macOS host (My Mac) or an iOS 17 simulator with a TrueDepth-capable device profile (e.g., iPhone 14 Pro).
4. Grant camera access when prompted. On macOS, Screen Recording/Accessibility permissions are only required when integrating with a custom overlay host; the sample app itself does not request them.

### Calibration workflow

1. Switch to the **Calibrate** tab.
2. Tap **Start** to walk through a 9-point calibration routine. Each fixation is sampled for ~400 ms.
3. Tap **Finish** to fit a ridge-regularized quadratic mapping. Metrics appear in the **Metrics** tab.

### Heatmap & trails controls

- Heatmap and trail overlays can be toggled directly from the Live view.
- The heatmap renders into a 96×54 grid with Gaussian blur and exponential decay. Trails keep ~3.5 s of data.

### Data export

Use `GazeViewModel.exportSamples(_:url:)` to export CSV/JSON payloads from app code. The demo surfaces JSON by default.

## Testing

Run the included unit test suite with:

```bash
swift test
```

## Continuous Integration

A GitHub Actions workflow (`.github/workflows/ci.yml`) is provided to build the package and execute tests on macOS runners.

## Known limitations

- The previewer implements the full gaze pipeline but omits the production menubar overlay target. Integrate `GazeTrackingKit` into a dedicated macOS app to extend functionality.
- ARKit eye tracking requires TrueDepth hardware and is only available on supported devices/simulators.
- System-wide overlays are not supported on iOS due to platform limitations; gaze rendering remains inside the host window.

## Privacy

- All computation and storage happen locally. No analytics or network communication.
- Camera frames are processed in-memory; no frames are persisted.
- A single “Start/Stop” toggle immediately pauses both capture and rendering.

## License

This repository is provided for demonstration and educational use. Review and adapt for production deployments as needed.
