import AppKit
import AVFoundation
import Combine
import WisprLocalCore

// wispr-local: hold the hotkey, talk, let go. Text lands in the focused field.

signal(SIGPIPE, SIG_IGN) // a helper that exits early must not take the app down
let permissionPollSeconds: TimeInterval = 1
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
if Paths.isApp { Paths.extendSearchPath() }

let options: Options
do {
    options = try Options.parse(Array(CommandLine.arguments.dropFirst()), defaultKey: Paths.isApp ? .fn : .rightOption)
} catch {
    log("\(error)\n\n\(Options.usage)")
    exit(2)
}
if options.showHelp {
    print(Options.usage)
    exit(0)
}
if !Paths.isApp && !ModelDownloader.isComplete {
    log("models missing in \(Paths.models.path). Run ./scripts/setup.sh from the repo folder.")
    exit(1)
}

let statusMenu = Paths.isApp ? StatusMenu() : nil
let server = WhisperServer(model: Paths.model(Paths.modelName), language: options.language)
let controller = Controller(options: options, server: server, timingLog: TimingLog(url: Paths.runs))
let downloader = ModelDownloader()
let state = AppState(key: (Paths.isApp ? Settings.key : nil) ?? options.key)
let mainWindow = MainWindow(state: state)
let appDelegate = AppDelegate()

func setStatus(_ text: String) {
    statusMenu?.setStatus(text)
    state.status = text
}

controller.onRecordingChange = {
    statusMenu?.setRecording($0)
    state.voice.setRecording($0)
}
controller.onLevel = { state.voice.hear($0) }
controller.onWords = { state.voice.words = $0 }
if Paths.isApp {
    state.history.purge() // also loads it, so retention applies even if the window is never opened
    state.onDeleteAll = {
        state.history.deleteAll()
        controller.forgetLast()
    }
    controller.onResult = { state.history.add($0, samples: $1) }
    controller.captureTarget = { mainWindow.captureTarget }
    statusMenu?.onOpen = { mainWindow.show() }
    statusMenu?.onRetry = controller.retryLast
    statusMenu?.canRetry = { controller.canRetry }
    appDelegate.onReopen = { mainWindow.show() }
    app.delegate = appDelegate
    app.mainMenu = AppDelegate.makeMenu()
}
NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in server.stop() }

func requestPermissions() {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let host = Paths.isApp ? Paths.appName : "your terminal app"
    if !AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) {
        log("grant Accessibility to \(host) (System Settings > Privacy & Security > Accessibility)")
    }
    AVCaptureDevice.requestAccess(for: .audio) { granted in
        if !granted { log("microphone access denied: allow it for \(host) in System Settings") }
    }
}

func handleFlags(_ event: NSEvent) {
    guard let pressed = state.key.isPressed(keyCode: event.keyCode, flags: event.modifierFlags.rawValue) else { return }
    if pressed { controller.keyDown() } else { controller.keyUp() }
}

var keyObserver: AnyCancellable?

func startListening() {
    // Global monitors miss events while our own window (the voice test) is in front, so watch both.
    NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handleFlags)
    NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { handleFlags($0); return $0 }
    for events in [NSEvent.EventTypeMask.keyDown, .leftMouseDown] {
        NSEvent.addLocalMonitorForEvents(matching: events) { event in
            if !Paster.isOurs(event) { controller.userActed() }
            return event
        }
    }
    NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in controller.userActed() }
    // Another key while holding means a shortcut such as fn+F5, not dictation.
    NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
        guard !Paster.isOurs(event) else { return } // pasting the last dictation must not cancel this one
        controller.userActed()
        controller.cancel()
    }
    state.isReady = true
    setStatus("Hold \(state.key.label) to talk")
    if Paths.isApp { keyObserver = state.$key.dropFirst().sink { setStatus("Hold \($0.label) to talk") } }
    log("ready. hold \(options.key.label) to talk\(options.cleanup ? "" : " (raw mode, no cleanup)")")
}

func waitForAccessibility() {
    if AXIsProcessTrusted() { return startListening() }
    // Key monitors installed before Accessibility is granted stay deaf, so wait for it.
    setStatus("Waiting for Accessibility permission")
    Timer.scheduledTimer(withTimeInterval: permissionPollSeconds, repeats: true) { timer in
        guard AXIsProcessTrusted() else { return }
        timer.invalidate()
        startListening()
    }
}

func begin() {
    DispatchQueue.global().async {
        // The first run of each tool is slow, so do it now with a second of silence.
        let silence = [Float](repeating: 0, count: Int(Recorder.sampleRate))
        _ = Pipeline.isSilent(silence)
        if options.cleanup { _ = OnDeviceCleaner.clean("Um, can you send me the the notes today?") }
        do { _ = try server.transcribe(silence) } catch { log("whisper failed to start: \(error)") }
    }
    waitForAccessibility()
}

requestPermissions()
if ModelDownloader.isComplete {
    begin()
} else {
    downloader.onProgress = { setStatus("Downloading speech model: \($0)%") }
    downloader.onFinish = { error in
        guard let error else { return begin() }
        log("download failed: \(error)")
        setStatus("Download failed. Quit and reopen to retry.")
    }
    setStatus("Downloading speech model\u{2026}")
    downloader.start()
}
app.run()
