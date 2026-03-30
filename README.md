# MoanBar

A native macOS menu bar utility that plays a sound (and optionally shows an anime image) every time you physically tap, slap, or hit your MacBook chassis.

---

## Requirements

| Item | Detail |
|---|---|
| Target hardware | Apple Silicon MacBook (Air / Pro) |
| Minimum macOS | 13.0 (Ventura) — required for `MenuBarExtra` SwiftUI API |
| Xcode | 15.3 or later (Swift 5.10) |
| Distribution | Direct download — **not** Mac App Store |

---

## Project structure

```
MoanBar/
├── App/            MoanBarApp.swift        — @main entry point, MenuBarExtra + Settings scenes
├── Sensor/         SensorProvider.swift    — protocol + SensorSample type
│                   SPUSensorProvider.swift — CoreMotion / IOKit real hardware path
│                   MockSensorProvider.swift— always-on simulation, used in dev/test
├── Detection/      SlapDetector.swift      — gravity removal → peak detection → SlapEvent
├── Audio/          AudioEngine.swift       — preloads clips, maps intensity → volume
├── Overlay/        OverlayEngine.swift     — floating image with fade in/out
│                   OverlayWindow.swift     — borderless non-activating NSPanel
├── Settings/       SettingsStore.swift     — UserDefaults-backed @Published settings
├── ViewModels/     AppViewModel.swift      — wires all subsystems via Combine
├── Views/          MenuBarView.swift       — status, counter, quick actions
│                   SettingsView.swift      — tabbed General / Audio / Diagnostics UI
│                   DiagnosticsView.swift   — live sensor readout, hit indicator
├── Utilities/      Logging.swift           — debug-only console + os.log
└── Resources/
    ├── Sounds/     ← drop your .mp3/.wav/.m4a clips here
    └── Images/     ← drop your .png/.jpg/.gif images here
```

---

## Building & running

1. Open `MoanBar.xcodeproj` in Xcode 15.3+.
2. Select your Apple Silicon Mac as the run destination.
3. Set your **Development Team** in *Signing & Capabilities* (or use personal team for local testing).
4. Build & run (`⌘R`). The app appears in the menu bar — no Dock icon.

### First run without assets

The app starts in **Mock Mode** automatically when no hardware sensor is detected (or when you toggle it in Settings). All UI, audio, and overlay paths work without real assets — you just won't hear anything until you drop clips into `Resources/Sounds/`.

---

## Adding sound & image assets

Drop files directly into the Xcode project's `Resources/Sounds/` and `Resources/Images/` folders (or drag them into the Xcode group). No code changes are needed — the engine scans the bundle folder at launch.

**Sounds:** `.mp3`, `.wav`, `.m4a`, `.aiff`, `.caf`
**Images:** `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.heic`

Recommended sound specs: ≤ 2 s, normalised to −14 LUFS, no silence tail.

---

## Hardware sensor — supported devices & known limitations

### What we try first: CoreMotion

`SPUSensorProvider` uses `CMMotionManager.isAccelerometerAvailable`. On macOS this returns `true` on some Apple Silicon MacBooks (particularly M1/M2 Air & Pro) and `false` on most desktop Macs and older Intel laptops.

### Fallback: Mock mode

If `isAccelerometerAvailable` returns `false`, the app automatically switches to `MockSensorProvider`. You'll see an orange "Mock mode" badge in the menu bar. You can also force Mock Mode in *Settings → General* for development without any hardware.

### Future: IOKit HID path

`SPUSensorProvider.swift` contains detailed comments on how to implement an IOKit HID path targeting the Apple Motion Group (AMG) sensor. This path can work even when CoreMotion reports unavailable, but is undocumented and fragile across OS updates. The interface is clean — replace the CoreMotion implementation body while keeping the `SensorProvider` protocol signature, and nothing else in the app needs to change.

### Elevated privileges

Neither the CoreMotion nor the standard IOKit HID path requires elevated privileges or a helper process for read-only accelerometer access. If a future sensor path requires a privileged helper (e.g., kernel extension or SMC access), scaffold it as a separate `XPC service` target and proxy samples over the IPC channel — the `SensorProvider` protocol boundary makes this straightforward.

---

## Settings reference

| Setting | Default | Notes |
|---|---|---|
| Enable MoanBar | on | Master on/off; stops the sensor when disabled |
| Enable sound | on | |
| Enable image overlay | on | |
| Mock mode | off | Forces `MockSensorProvider` |
| Sensitivity | 1.5 g | Threshold for slap detection; lower = more sensitive |
| Cooldown | 0.4 s | Minimum time between events |
| Min volume | 10 % | Volume at gentlest detected tap |
| Max volume | 90 % | Volume at hardest detected slap |
| Launch at login | — | Scaffolded; requires `SMAppService` wiring |

---

## Signing & notarization for direct distribution

1. Enable **Hardened Runtime** (already set in the project).
2. The entitlements file (`MoanBar.entitlements`) disables the sandbox — correct for non-App Store distribution.
3. To notarize: `xcrun notarytool submit MoanBar.zip --apple-id … --team-id … --password …`
4. Then staple: `xcrun stapler staple MoanBar.app`

---

## Renaming the app

1. Rename the Xcode target and product in project settings.
2. Update `CFBundleName`, `CFBundleDisplayName`, `CFBundleIdentifier` in `Info.plist`.
3. Update `PRODUCT_BUNDLE_IDENTIFIER` in both build configurations.
4. Rename the source group folder in Xcode navigator (and on disk if needed).

---

## Detection pipeline summary

```
Raw x/y/z (100 Hz)
  │
  ▼
Low-pass filter (α=0.97) → gravity estimate (gx, gy, gz)
  │
  ▼
Gravity removal → dynamic acceleration (dx, dy, dz)
  │
  ▼
Magnitude = √(dx²+dy²+dz²)
  │
  ▼
Threshold gate (configurable, default 1.5 g)
  │ magnitude > threshold AND cooldown elapsed
  ▼
Peak tracker (accumulates peak while above threshold)
  │ magnitude < 0.5 × threshold  (hysteresis)
  ▼
SlapEvent(intensity = peak / maxIntensityG, clamped 0…1)
  │
  ├─▶ AudioEngine.play(intensity)   → random clip, volume ∝ intensity
  └─▶ OverlayEngine.show()          → random image, 2 s fade in/out
```
