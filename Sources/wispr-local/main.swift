import AppKit
import AVFoundation
import WisprLocalCore

// wispr-local: hold right Option, talk, let go. Text lands in the focused field.

let rightOptionKeyCode: UInt16 = 61
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let model = root.appendingPathComponent("models/ggml-large-v3-turbo-q5_0.bin")

let options: Options
do {
    options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    log("\(error)\n\n\(Options.usage)")
    exit(2)
}
if options.showHelp {
    print(Options.usage)
    exit(0)
}
guard FileManager.default.fileExists(atPath: model.path) else {
    log("model missing at \(model.path). Run from the repo root after the setup steps in README.md.")
    exit(1)
}

func requestPermissions() {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    if !AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) {
        log("grant Accessibility to your terminal app (System Settings > Privacy & Security > Accessibility), then restart")
    }
    AVCaptureDevice.requestAccess(for: .audio) { granted in
        if !granted { log("microphone access denied: allow it for your terminal app in System Settings") }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
requestPermissions()

let controller = Controller(options: options, model: model, timingLog: TimingLog(url: root.appendingPathComponent("runs.csv")))
NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
    guard event.keyCode == rightOptionKeyCode else { return }
    if event.modifierFlags.contains(.option) { controller.keyDown() } else { controller.keyUp() }
}

log("ready. hold right Option to talk\(options.cleanup ? "" : " (raw mode, no cleanup)")")
app.run()
