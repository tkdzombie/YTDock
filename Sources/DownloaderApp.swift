import SwiftUI
import AppKit
import Foundation
import Combine
import Darwin
import UserNotifications

// MARK: - Build metadata

enum BuildInfo {
    static let version = "__DOWNLOADER_VERSION__"
    static let minimumMacOS = "12.0"
}

// MARK: - Download model

enum DownloadState: String, CaseIterable {
    case queued
    case parsing
    case ready
    case waiting
    case downloading
    case paused
    case done
    case failed
    case cancelled

    var title: String {
        switch self {
        case .queued: return "等待解析"
        case .parsing: return "解析中"
        case .ready: return "可下载"
        case .waiting: return "等待下载"
        case .downloading: return "下载中"
        case .paused: return "已暂停"
        case .done: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }

    var symbol: String {
        switch self {
        case .queued: return "clock"
        case .parsing: return "sparkles"
        case .ready: return "play.circle"
        case .waiting: return "hourglass"
        case .downloading: return "arrow.down.circle.fill"
        case .paused: return "pause.circle.fill"
        case .done: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .done: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        case .downloading: return .accentColor
        case .paused: return .orange
        default: return .secondary
        }
    }

    var isActive: Bool {
        [.queued, .parsing, .waiting, .downloading, .paused].contains(self)
    }
}

enum QualityPreset: Int, CaseIterable, Identifiable {
    case bestMP4
    case upTo4K
    case upTo1080p
    case upTo720p
    case audioOnly

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .bestMP4: return "最佳 MP4"
        case .upTo4K: return "最高 4K"
        case .upTo1080p: return "最高 1080p"
        case .upTo720p: return "最高 720p"
        case .audioOnly: return "仅音频"
        }
    }

    var formatSelector: String {
        switch self {
        case .bestMP4:
            return "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best"
        case .upTo4K:
            return "bestvideo[height<=2160]+bestaudio/bestvideo[height<=2160]/best[height<=2160]/best"
        case .upTo1080p:
            return "bestvideo[height<=1080]+bestaudio/bestvideo[height<=1080]/best[height<=1080]/best"
        case .upTo720p:
            return "bestvideo[height<=720]+bestaudio/bestvideo[height<=720]/best[height<=720]/best"
        case .audioOnly:
            return "bestaudio[ext=m4a]/bestaudio"
        }
    }
}

enum QueueFilter: Int, CaseIterable, Identifiable {
    case all
    case active
    case completed
    case issues

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .all: return "全部"
        case .active: return "进行中"
        case .completed: return "已完成"
        case .issues: return "异常"
        }
    }
}

@MainActor
final class DownloadItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: String
    let quality: QualityPreset

    @Published var title = "等待解析链接"
    @Published var subtitle = ""
    @Published var state: DownloadState = .queued
    @Published var progress: Double = 0
    @Published var speed = ""
    @Published var eta = ""
    @Published var totalSize = ""
    @Published var thumbnailURL: URL?
    @Published var outputPath = ""
    @Published var errorMessage = ""
    var expectedDuration: Double = 0
    var downloadedDuration: Double = 0

    var metadataLoaded = false
    var autoDownload = false
    var removeAfterFinish = false
    var automaticRetryCount = 0

    init(url: String, quality: QualityPreset) {
        self.url = url
        self.quality = quality
        self.subtitle = url
    }
}

// MARK: - Download manager / Downloader Core

@MainActor
final class DownloadManager: ObservableObject {
    @Published var inputText = ""
    @Published var items: [DownloadItem] = []
    @Published var quality: QualityPreset = .bestMP4
    @Published var filter: QueueFilter = .all
    @Published var outputFolder: URL
    @Published var statusText = "就绪"
    @Published var hintText = "粘贴或拖入链接即可开始"
    @Published var clipboardURL = ""
    @Published var logs = ""
    @Published var showLogs = false
    @Published var showAbout = false
    @Published var completionNotifications = false

    private enum RunKind { case metadata, download }
    private var process: Process?
    private var runKind: RunKind?
    private weak var activeItem: DownloadItem?
    private var stdoutBuffer = ""
    private var metadataOutput = ""
    private var processDiagnostic = ""
    private var intendedCancel = false
    private var tempDirectory: URL
    private var clipboardChangeCount = -1

    private let ytdlp: URL
    private let deno: URL
    private let ffmpeg: URL

    init() {
        self.outputFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
        let resources = Bundle.main.resourceURL ?? URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("Contents/Resources")
        let tools = resources.appendingPathComponent("Tools", isDirectory: true)
        self.ytdlp = tools.appendingPathComponent("yt-dlp")
        self.deno = tools.appendingPathComponent("deno")
        self.ffmpeg = tools.appendingPathComponent("ffmpeg")
        self.tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("Downloader-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        verifyBundledTools()
        checkClipboard()
    }

    deinit {
        if let process, process.isRunning {
            _ = kill(process.processIdentifier, SIGCONT)
            process.terminate()
        }
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    var visibleItems: [DownloadItem] {
        switch filter {
        case .all: return items
        case .active: return items.filter { $0.state.isActive }
        case .completed: return items.filter { $0.state == .done }
        case .issues: return items.filter { [.failed, .cancelled].contains($0.state) }
        }
    }

    var summary: String {
        if items.isEmpty { return "暂无任务" }
        let active = items.filter { $0.state.isActive }.count
        let done = items.filter { $0.state == .done }.count
        let failed = items.filter { $0.state == .failed }.count
        var parts = ["\(items.count) 个任务"]
        if active > 0 { parts.append("\(active) 进行中") }
        if done > 0 { parts.append("\(done) 完成") }
        if failed > 0 { parts.append("\(failed) 异常") }
        return parts.joined(separator: " · ")
    }

    var hasClearableItems: Bool {
        items.contains { [.done, .failed, .cancelled].contains($0.state) }
    }

    var hasDownloadableItems: Bool {
        items.contains { [.queued, .ready, .failed, .cancelled].contains($0.state) }
    }

    var runtimeSummary: String {
        let versions = ytdlp.deletingLastPathComponent().appendingPathComponent("versions.txt")
        guard let text = try? String(contentsOf: versions, encoding: .utf8) else {
            return "yt-dlp · Deno · FFmpeg"
        }
        return text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { $0.replacingOccurrences(of: "=", with: " ") }
            .joined(separator: " · ")
    }

    var buildArchitecture: String {
        (Bundle.main.object(forInfoDictionaryKey: "DownloaderBuildArchitecture") as? String) ?? Self.machineArchitecture()
    }

    func addInput(autoStart: Bool = false) {
        addLinks(from: inputText, autoStart: autoStart)
        inputText = ""
    }

    func addClipboard() {
        guard !clipboardURL.isEmpty else {
            statusText = "剪贴板没有链接"
            hintText = "复制一个 http 或 https 链接后再试"
            return
        }
        addLinks(from: clipboardURL, autoStart: false)
    }

    func addLinks(from text: String, autoStart: Bool) {
        let links = Self.extractLinks(from: text)
        guard !links.isEmpty else {
            statusText = "没有检测到链接"
            hintText = "支持 http / https 链接"
            return
        }

        var added = 0
        for link in links {
            let duplicate = items.contains { $0.url == link && ![.failed, .cancelled].contains($0.state) }
            guard !duplicate else { continue }
            let item = DownloadItem(url: link, quality: quality)
            item.autoDownload = autoStart
            items.append(item)
            added += 1
        }

        guard added > 0 else {
            statusText = "链接已在队列中"
            hintText = "Downloader 不会重复添加相同的活动任务"
            return
        }
        statusText = "已加入队列"
        hintText = "\(added) 个链接等待解析"
        objectWillChange.send()
        processNext()
    }

    func downloadAll() {
        for item in items {
            switch item.state {
            case .queued, .parsing:
                item.autoDownload = true
            case .ready:
                item.autoDownload = true
                item.state = .waiting
            case .failed, .cancelled:
                item.errorMessage = ""
                item.autoDownload = true
                item.automaticRetryCount = 0
                item.state = item.metadataLoaded ? .waiting : .queued
            default:
                break
            }
        }
        statusText = "已加入下载队列"
        hintText = "Downloader 会先解析，再按顺序下载"
        objectWillChange.send()
        processNext()
    }

    func primaryAction(for item: DownloadItem) {
        switch item.state {
        case .done:
            reveal(item)
        case .downloading:
            pause(item)
        case .paused:
            resume(item)
        case .parsing:
            cancel(item)
        case .waiting:
            item.autoDownload = false
            item.state = .ready
            objectWillChange.send()
        case .ready:
            item.autoDownload = true
            item.state = .waiting
            objectWillChange.send()
            processNext()
        case .failed, .cancelled:
            item.errorMessage = ""
            item.autoDownload = true
            item.automaticRetryCount = 0
            item.state = item.metadataLoaded ? .waiting : .queued
            objectWillChange.send()
            processNext()
        case .queued:
            item.autoDownload = true
            processNext()
        }
    }

    func remove(_ item: DownloadItem) {
        if activeItem === item, let process, process.isRunning {
            item.removeAfterFinish = true
            intendedCancel = true
            if item.state == .paused { _ = kill(process.processIdentifier, SIGCONT) }
            process.terminate()
            item.state = .cancelled
            statusText = "正在取消"
            objectWillChange.send()
            return
        }
        items.removeAll { $0.id == item.id }
        objectWillChange.send()
    }

    func clearFinished() {
        items.removeAll { [.done, .failed, .cancelled].contains($0.state) }
        objectWillChange.send()
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.directoryURL = outputFolder
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
        }
    }

    func openOutputFolder() {
        NSWorkspace.shared.open(outputFolder)
    }

    func reveal(_ item: DownloadItem) {
        guard !item.outputPath.isEmpty else {
            openOutputFolder()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.outputPath)])
    }

    func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != clipboardChangeCount else { return }
        clipboardChangeCount = pasteboard.changeCount
        let text = pasteboard.string(forType: .string) ?? ""
        clipboardURL = Self.extractLinks(from: text).first ?? ""
    }

    func enableNotifications(_ enabled: Bool) {
        completionNotifications = enabled
        guard enabled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func copyDiagnostics() {
        let details = """
        Downloader \(BuildInfo.version)
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        architecture \(Self.machineArchitecture())
        output \(outputFolder.path)
        tasks \(items.count)

        \(logs)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(details, forType: .string)
        statusText = "诊断信息已复制"
    }

    // MARK: Queue engine

    private func processNext() {
        guard process == nil else { return }

        if let item = items.first(where: { $0.state == .queued }) {
            startMetadata(item)
            return
        }
        if let item = items.first(where: { $0.state == .waiting }) {
            startDownload(item)
            return
        }

        if items.contains(where: { $0.state == .ready }) {
            statusText = "等待下载"
            hintText = "选择任务下载，或点击“全部下载”"
        } else if items.allSatisfy({ $0.state == .done || $0.state == .failed || $0.state == .cancelled }) && !items.isEmpty {
            statusText = "队列已完成"
            hintText = summary
        } else if items.isEmpty {
            statusText = "就绪"
            hintText = "粘贴或拖入链接即可开始"
        }
    }

    private func startMetadata(_ item: DownloadItem) {
        item.state = .parsing
        item.errorMessage = ""
        statusText = "正在解析"
        hintText = item.url
        objectWillChange.send()

        var arguments = [
            "--ignore-config", "--no-cache-dir", "--no-playlist",
            "--skip-download", "--dump-single-json", "--no-warnings",
            "--js-runtimes", "deno:\(deno.path)",
            // Modern YouTube extraction requires yt-dlp's external EJS
            // challenge scripts in addition to a JavaScript runtime.
            "--remote-components", "ejs:github"
        ]
        arguments.append(item.url)
        startProcess(kind: .metadata, item: item, executable: ytdlp, arguments: arguments)
    }

    private func startDownload(_ item: DownloadItem) {
        item.state = .downloading
        item.progress = 0
        item.speed = ""
        item.eta = ""
        item.totalSize = ""
        item.errorMessage = ""
        statusText = "下载中"
        hintText = item.title
        objectWillChange.send()

        var arguments = [
            "--ignore-config", "--no-cache-dir", "--newline", "--no-colors", "--no-playlist",
            "--continue",
            "--no-overwrites",
            "--force-ipv4",
            "--retries", "10",
            "--fragment-retries", "10",
            "--file-access-retries", "5",
            "--retry-sleep", "exp=1:10",
            "--socket-timeout", "30",
            "--concurrent-fragments", "4",
            "--http-chunk-size", "10M",
            "--merge-output-format", "mp4",
            "--trim-filenames", "180",
            "--paths", outputFolder.path,
            "--output", "%(title)s [%(id)s].%(ext)s",
            "--format", item.quality.formatSelector,
            "--ffmpeg-location", ffmpeg.path,
            "--progress-template", "download:YTDPROGRESS:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._total_bytes_str)s",
            "--print", "after_move:YTDOUTPUT:%(filepath)s",
            "--print", "after_move:YDTDURATION:%(duration)s",
            "--js-runtimes", "deno:\(deno.path)",
            "--remote-components", "ejs:github"
        ]
        arguments.append(item.url)
        startProcess(kind: .download, item: item, executable: ytdlp, arguments: arguments)
    }

    private func startProcess(kind: RunKind, item: DownloadItem, executable: URL, arguments: [String]) {
        let proc = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.executableURL = executable
        proc.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        env["DENO_DIR"] = tempDirectory.appendingPathComponent("DenoCache", isDirectory: true).path
        env["NO_COLOR"] = "1"
        proc.environment = env
        proc.standardOutput = stdout
        proc.standardError = stderr

        self.process = proc
        self.runKind = kind
        self.activeItem = item
        self.stdoutBuffer = ""
        self.metadataOutput = ""
        self.processDiagnostic = ""
        self.intendedCancel = false

        appendLog("\n— \(kind == .metadata ? "解析" : "下载") · \(item.url) —\n")

        // FileHandle/Process callbacks are @Sendable on current macOS SDKs.  Keep
        // immutable strong references here and hop back to MainActor before touching
        // Downloader state.  Weak capture lists create mutable capture boxes, which Swift
        // 6 rejects as "reference to captured var ... in concurrently-executing code".
        let manager = self
        let processItem = item

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                manager.consumeOutput(chunk, isError: false)
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                manager.consumeOutput(chunk, isError: true)
            }
        }

        proc.terminationHandler = { finished in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            let outTail = stdout.fileHandleForReading.readDataToEndOfFile()
            let errTail = stderr.fileHandleForReading.readDataToEndOfFile()
            let outText = String(data: outTail, encoding: .utf8) ?? ""
            let errText = String(data: errTail, encoding: .utf8) ?? ""
            let terminationStatus = finished.terminationStatus
            Task { @MainActor in
                if !outText.isEmpty { manager.consumeOutput(outText, isError: false) }
                if !errText.isEmpty { manager.consumeOutput(errText, isError: true) }
                manager.finishProcess(item: processItem, code: terminationStatus)
            }
        }

        do {
            try proc.run()
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            proc.terminationHandler = nil
            appendLog("启动下载引擎失败：\(error.localizedDescription)\n")
            item.state = .failed
            item.errorMessage = "无法启动内置下载引擎。请重新下载 Downloader。"
            self.process = nil
            self.runKind = nil
            self.activeItem = nil
            objectWillChange.send()
            processNext()
        }
    }

    private func consumeOutput(_ chunk: String, isError: Bool) {
        appendLog(chunk)
        processDiagnostic += chunk
        if processDiagnostic.count > 80_000 { processDiagnostic = String(processDiagnostic.suffix(60_000)) }
        if runKind == .metadata, !isError {
            metadataOutput += chunk
            return
        }

        guard runKind == .download, !isError, let item = activeItem else { return }
        stdoutBuffer += chunk
        let parts = stdoutBuffer.components(separatedBy: .newlines)
        stdoutBuffer = parts.last ?? ""
        for line in parts.dropLast() {
            parseDownloadLine(line, item: item)
        }
    }

    private func parseDownloadLine(_ line: String, item: DownloadItem) {
        if line.hasPrefix("YTDPROGRESS:") {
            let payload = String(line.dropFirst("YTDPROGRESS:".count))
            let fields = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if !fields.isEmpty {
                let pctText = fields[0].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                item.progress = min(100, max(0, Double(pctText) ?? item.progress))
            }
            if fields.count > 1 { item.speed = fields[1].trimmingCharacters(in: .whitespaces) }
            if fields.count > 2 { item.eta = fields[2].trimmingCharacters(in: .whitespaces) }
            if fields.count > 3 { item.totalSize = fields[3].trimmingCharacters(in: .whitespaces) }
            objectWillChange.send()
        } else if line.hasPrefix("YTDOUTPUT:") {
            item.outputPath = String(line.dropFirst("YTDOUTPUT:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if line.hasPrefix("YDTDURATION:") {
            item.downloadedDuration = Double(String(line.dropFirst("YDTDURATION:".count)).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }
    }

    private func finishProcess(item: DownloadItem, code: Int32) {
        let kind = runKind
        if kind == .download, !stdoutBuffer.isEmpty {
            parseDownloadLine(stdoutBuffer, item: item)
            stdoutBuffer = ""
        }
        let wasCancelled = intendedCancel
        process = nil
        runKind = nil
        activeItem = nil
        intendedCancel = false

        if item.removeAfterFinish {
            items.removeAll { $0.id == item.id }
            objectWillChange.send()
            processNext()
            return
        }

        switch kind {
        case .metadata:
            if code == 0, applyMetadata(to: item, jsonText: metadataOutput) {
                item.metadataLoaded = true
                item.state = item.autoDownload ? .waiting : .ready
                statusText = "解析完成"
                hintText = item.title
            } else {
                item.state = wasCancelled ? .cancelled : .failed
                item.errorMessage = friendlyError(from: processDiagnostic)
                statusText = wasCancelled ? "已取消" : "解析失败"
                hintText = item.errorMessage
            }
        case .download:
            if code == 0 {
                if item.expectedDuration >= 30, item.downloadedDuration > 0,
                   item.downloadedDuration + 15 < item.expectedDuration {
                    item.state = .failed
                    item.errorMessage = "下载内容时长为 \(Self.durationString(item.downloadedDuration))，页面显示 \(Self.durationString(item.expectedDuration))。可能只下载了试看部分；请在公开可获取的链接中重试。"
                    statusText = "下载内容不完整"
                    hintText = item.errorMessage
                    objectWillChange.send()
                    processNext()
                    return
                }
                item.automaticRetryCount = 0
                item.state = .done
                item.progress = 100
                statusText = "下载完成"
                hintText = item.title
                deliverCompletionNotification(for: item)
            } else if wasCancelled {
                item.state = .cancelled
                statusText = "已取消"
                hintText = item.title
            } else if item.automaticRetryCount < 2 {
                item.automaticRetryCount += 1
                item.state = .waiting
                statusText = "下载中断，正在自动重试 \(item.automaticRetryCount)/2"
                hintText = item.title
                objectWillChange.send()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.processNext()
                }
                return
            } else {
                item.automaticRetryCount = 0
                item.state = .failed
                item.errorMessage = friendlyError(from: processDiagnostic)
                statusText = "下载失败"
                hintText = item.errorMessage
            }
        case .none:
            break
        }

        objectWillChange.send()
        processNext()
    }

    private func applyMetadata(to item: DownloadItem, jsonText: String) -> Bool {
        guard let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        if let title = object["title"] as? String, !title.isEmpty { item.title = title }
        let site = (object["extractor_key"] as? String) ?? (object["extractor"] as? String) ?? Self.hostName(from: item.url)
        let uploader = (object["uploader"] as? String) ?? (object["channel"] as? String) ?? ""
        let duration: String = {
            if let value = object["duration_string"] as? String { return value }
            if let seconds = object["duration"] as? Double { return Self.durationString(seconds) }
            if let seconds = object["duration"] as? Int { return Self.durationString(Double(seconds)) }
            return ""
        }()
        if let seconds = object["duration"] as? Double { item.expectedDuration = seconds }
        if let seconds = object["duration"] as? Int { item.expectedDuration = Double(seconds) }
        item.subtitle = [site, uploader, duration].filter { !$0.isEmpty }.joined(separator: " · ")
        if let thumb = object["thumbnail"] as? String { item.thumbnailURL = URL(string: thumb) }
        item.errorMessage = ""
        return true
    }

    private func pause(_ item: DownloadItem) {
        guard activeItem === item, let process, process.isRunning else { return }
        if kill(process.processIdentifier, SIGSTOP) == 0 {
            item.state = .paused
            statusText = "已暂停"
            hintText = item.title
            objectWillChange.send()
        }
    }

    private func resume(_ item: DownloadItem) {
        guard activeItem === item, let process, process.isRunning else { return }
        if kill(process.processIdentifier, SIGCONT) == 0 {
            item.state = .downloading
            statusText = "下载中"
            hintText = item.title
            objectWillChange.send()
        }
    }

    private func cancel(_ item: DownloadItem) {
        guard activeItem === item, let process, process.isRunning else { return }
        intendedCancel = true
        if item.state == .paused { _ = kill(process.processIdentifier, SIGCONT) }
        process.terminate()
        item.state = .cancelled
        objectWillChange.send()
    }

    private func verifyBundledTools() {
        let required = [("yt-dlp", ytdlp), ("Deno", deno), ("FFmpeg", ffmpeg)]
        let missing = required.filter { !FileManager.default.isExecutableFile(atPath: $0.1.path) }.map(\.0)
        if missing.isEmpty {
            statusText = "就绪"
        } else {
            statusText = "运行组件缺失"
            hintText = "缺少：\(missing.joined(separator: ", "))。请重新下载完整 DMG。"
        }
    }

    private func friendlyError(from text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("drm") || lower.contains("encrypted") || lower.contains("protected content") {
            return "该视频受到 DRM 或加密保护，普通下载方式无法处理。"
        }
        if lower.contains("javascript runtime") || lower.contains("challenge solving failed") || lower.contains("ejs") {
            return "站点验证失败或内容不是公开可获取内容。请确认链接可公开播放后重试。"
        }
        if lower.contains("requested format is not available") {
            return "当前内容没有所选清晰度。请切换到“最佳 MP4”或较低清晰度后重试。"
        }
        if lower.contains("unsupported url") {
            return "暂不支持这个链接，或链接格式无法识别。"
        }
        if lower.contains("http error 403") || lower.contains("forbidden") {
            return "服务器拒绝了公开下载请求（403）。请确认内容可公开访问后稍后重试。"
        }
        if lower.contains("http error 429") || lower.contains("too many requests") {
            return "请求过于频繁（429）。建议稍后再试。"
        }
        if lower.contains("video unavailable") || lower.contains("this video is unavailable") {
            return "这个视频当前不可用，可能已删除、受地区限制或不支持公开下载。"
        }
        if lower.contains("ffmpeg") && (lower.contains("not found") || lower.contains("not installed")) {
            return "内置 FFmpeg 不可用。请重新下载完整 Downloader。"
        }

        let candidate = text.components(separatedBy: .newlines)
            .reversed()
            .first { line in
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return !t.isEmpty && (t.localizedCaseInsensitiveContains("error") || t.localizedCaseInsensitiveContains("failed"))
            }
        if let candidate {
            return candidate.replacingOccurrences(of: "ERROR:", with: "").trimmingCharacters(in: .whitespaces)
        }
        return "任务没有完成。打开“运行详情”可以查看原始诊断信息。"
    }

    private func appendLog(_ text: String) {
        logs += text
        if logs.count > 240_000 { logs = String(logs.suffix(180_000)) }
    }

    private func deliverCompletionNotification(for item: DownloadItem) {
        guard completionNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "Downloader 下载完成"
        content.body = item.title
        content.sound = .default
        let request = UNNotificationRequest(identifier: "downloader-\(item.id.uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func extractLinks(from text: String) -> [String] {
        let pattern = #"https?://[^\s<>\"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var links: [String] = []
        for match in regex.matches(in: text, range: range) {
            guard let r = Range(match.range, in: text) else { continue }
            var value = String(text[r])
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: ")]}>，。；、,"))
            guard URL(string: value)?.scheme != nil, !links.contains(value) else { continue }
            links.append(value)
        }
        return links
    }

    private static func hostName(from string: String) -> String {
        URL(string: string)?.host?.replacingOccurrences(of: "www.", with: "") ?? "网页"
    }


    private static func durationString(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private static func machineArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let bytes = mirror.children.compactMap { $0.value as? Int8 }.prefix { $0 != 0 }
        return String(bytes: bytes.map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? "unknown"
    }
}

// MARK: - UI

struct MainView: View {
    @EnvironmentObject private var manager: DownloadManager
    @State private var dropTarget = false
    private let clipboardTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            inputArea
            queueHeader
            queueArea
            settingsBar
            footer
        }
        .frame(minWidth: 900, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(clipboardTimer) { _ in manager.checkClipboard() }
        .sheet(isPresented: $manager.showLogs) { LogsView().environmentObject(manager) }
        .sheet(isPresented: $manager.showAbout) { AboutView().environmentObject(manager) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Downloader")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(manager.hintText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HeaderButton(symbol: "info.circle", help: "关于与安全") { manager.showAbout = true }
            HeaderButton(symbol: "waveform.path.ecg", help: "运行详情") { manager.showLogs = true }
            HeaderButton(symbol: "folder", help: "打开下载文件夹") { manager.openOutputFolder() }
            Text(manager.statusText)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.secondary.opacity(0.08), in: Capsule())
                .lineLimit(1)
        }
        .padding(.horizontal, 30)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private var inputArea: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)
            TextField("粘贴一个或多个链接…", text: $manager.inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit { manager.addInput() }
            Button {
                manager.addClipboard()
            } label: {
                Label(manager.clipboardURL.isEmpty ? "剪贴板" : "加入剪贴板链接", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered)
            Button {
                manager.addInput()
            } label: {
                Label("加入队列", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(DownloadManager.extractLinks(from: manager.inputText).isEmpty)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(dropTarget ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: dropTarget ? 2 : 1)
        }
        .padding(.horizontal, 30)
        .onDrop(of: ["public.url", "public.utf8-plain-text", "public.text"], isTargeted: $dropTarget) { providers in
            handleDrop(providers)
        }
    }

    private var queueHeader: some View {
        HStack {
            Text("下载队列")
                .font(.system(size: 14, weight: .semibold))
            Text(manager.summary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("筛选", selection: $manager.filter) {
                ForEach(QueueFilter.allCases) { filter in Text(filter.title).tag(filter) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 250)
            Button {
                manager.clearFinished()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .help("清理完成/失败/取消的任务")
            .disabled(!manager.hasClearableItems)
            Button {
                manager.downloadAll()
            } label: {
                Label("全部下载", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!manager.hasDownloadableItems)
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var queueArea: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if manager.visibleItems.isEmpty {
                    EmptyQueueView(filter: manager.filter)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 46)
                } else {
                    ForEach(manager.visibleItems) { item in
                        DownloadCard(item: item)
                            .environmentObject(manager)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("格式").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Picker("格式", selection: $manager.quality) {
                    ForEach(QualityPreset.allCases) { preset in Text(preset.title).tag(preset) }
                }
                .labelsHidden().frame(width: 150)

                Divider().frame(height: 24)

                                Text("保存到").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Text(manager.outputFolder.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("更改") { manager.chooseOutputFolder() }
                    .buttonStyle(.bordered)

                Toggle("完成通知", isOn: Binding(
                    get: { manager.completionNotifications },
                    set: { manager.enableNotifications($0) }
                ))
                .toggleStyle(.switch)
                .font(.system(size: 11))
            }
            Text("每个任务在加入队列时锁定格式 · 仅处理公开可获取内容 · 无后台服务 · 删除 App 即卸载")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 30)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        HStack {
            Text("Downloader \(BuildInfo.version) · Public Media Downloader")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            Text("仅下载公开可获取的内容")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 14)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                accepted = true
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, _ in
                    let value: String?
                    if let url = item as? URL { value = url.absoluteString }
                    else if let data = item as? Data { value = String(data: data, encoding: .utf8) }
                    else { value = item as? String }
                    guard let value else { return }
                    Task { @MainActor in manager.addLinks(from: value, autoStart: false) }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") || provider.hasItemConformingToTypeIdentifier("public.text") {
                accepted = true
                provider.loadItem(forTypeIdentifier: "public.utf8-plain-text", options: nil) { item, _ in
                    let value: String?
                    if let data = item as? Data { value = String(data: data, encoding: .utf8) }
                    else { value = item as? String }
                    guard let value else { return }
                    Task { @MainActor in manager.addLinks(from: value, autoStart: false) }
                }
            }
        }
        return accepted
    }
}

struct DownloadCard: View {
    @EnvironmentObject private var manager: DownloadManager
    @ObservedObject var item: DownloadItem

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
                .frame(width: 138, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Label(item.state.title, systemImage: item.state.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(item.state.tint)
                }

                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: progressValue)
                    .progressViewStyle(.linear)
                    .opacity(showProgress ? 1 : 0.28)

                HStack(spacing: 8) {
                    Text(detailText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(item.state == .failed ? .red : .secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(item.quality.title)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(spacing: 8) {
                Button(actionTitle) { manager.primaryAction(for: item) }
                    .buttonStyle(.borderedProminent)
                    .frame(width: 104)
                Button {
                    manager.remove(item)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .help("从队列移除")
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.055), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = item.thumbnailURL {
            ThumbnailView(url: url)
        } else {
            fallbackThumbnail
        }
    }

    private var fallbackThumbnail: some View {
        ZStack {
            Color.secondary.opacity(0.07)
            Image(systemName: item.state.symbol)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
        }
    }

    private var showProgress: Bool {
        [.downloading, .paused, .done].contains(item.state)
    }

    private var progressValue: Double {
        item.state == .done ? 1 : item.progress / 100
    }

    private var detailText: String {
        if item.state == .failed, !item.errorMessage.isEmpty { return item.errorMessage }
        if item.state == .cancelled { return "任务已取消，可点击“重试”重新加入队列" }
        if item.state == .downloading || item.state == .paused {
            var parts: [String] = []
            if item.progress > 0 { parts.append(String(format: "%.1f%%", item.progress)) }
            if !item.speed.isEmpty { parts.append(item.speed) }
            if !item.totalSize.isEmpty { parts.append(item.totalSize) }
            if !item.eta.isEmpty { parts.append("剩余 \(item.eta)") }
            return parts.isEmpty ? "正在准备下载…" : parts.joined(separator: " · ")
        }
        if item.state == .done {
            return item.outputPath.isEmpty ? "下载完成" : URL(fileURLWithPath: item.outputPath).lastPathComponent
        }
        if item.state == .ready { return "已解析，可开始下载" }
        if item.state == .waiting { return "等待前面的任务完成" }
        if item.state == .parsing { return "正在读取标题、来源、时长和缩略图" }
        return "等待 Downloader 解析链接"
    }

    private var actionTitle: String {
        switch item.state {
        case .done: return "Finder"
        case .downloading: return "暂停"
        case .paused: return "继续"
        case .parsing: return "取消"
        case .waiting: return "停止等待"
        case .failed, .cancelled: return "重试"
        case .ready, .queued: return "下载"
        }
    }
}

private struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?
    @State private var loading = true

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else if loading {
                ZStack { Color.secondary.opacity(0.07); ProgressView().controlSize(.small) }
            } else {
                ZStack {
                    Color.secondary.opacity(0.07)
                    Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(.secondary)
                }
            }
        }
        .task(id: url) {
            loading = true
            image = await Self.load(url: url)
            loading = false
        }
    }

    private static func load(url: URL) async -> NSImage? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let image = NSImage(data: data) else { return nil }
        return image
    }
}

struct EmptyQueueView: View {
    let filter: QueueFilter
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: filter == .all ? "arrow.down.doc" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(filter == .all ? "还没有下载任务" : "这个筛选条件下没有任务")
                .font(.system(size: 14, weight: .semibold))
            Text(filter == .all ? "粘贴链接、拖入链接，或从剪贴板加入" : "切换筛选条件查看其他任务")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

struct HeaderButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 22, height: 22)
        }
        .buttonStyle(.bordered)
        .help(help)
    }
}

struct LogsView: View {
    @EnvironmentObject private var manager: DownloadManager
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("运行详情").font(.title2.bold())
                    Text("用于排查下载失败；正常使用不需要查看。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("复制诊断") { manager.copyDiagnostics() }
                Button("完成") { manager.showLogs = false }.keyboardShortcut(.defaultAction)
            }
            ScrollView {
                Text(manager.logs.isEmpty ? "暂无运行日志。" : manager.logs)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        .frame(width: 720, height: 460)
    }
}

struct AboutView: View {
    @EnvironmentObject private var manager: DownloadManager
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            Text("Downloader").font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Version \(BuildInfo.version) · \(manager.buildArchitecture)").font(.caption).foregroundStyle(.secondary)
            Text(manager.runtimeSummary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text("一款专注于 macOS 下载工作流的独立应用。Downloader 自己负责界面、队列、任务状态、错误解释、交互与发行工程；媒体提取和处理由捆绑的第三方引擎完成。")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 430)
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Label("原生 SwiftUI 主程序", systemImage: "swift")
                Label("无后台服务 / 无 LaunchAgent / 无历史数据库", systemImage: "hand.raised")
                Label("发行依赖固定版本并校验 SHA-256", systemImage: "checkmark.shield")
                Label("免费构建为 ad-hoc 签名，不是 Developer ID / notarized", systemImage: "info.circle")
            }
            .font(.system(size: 11))
            Button("完成") { manager.showAbout = false }.keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 520, height: 420)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct DownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = DownloadManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(manager)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(after: .newItem) {
                Button("从剪贴板加入链接") { manager.addClipboard() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button("打开下载文件夹") { manager.openOutputFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}
