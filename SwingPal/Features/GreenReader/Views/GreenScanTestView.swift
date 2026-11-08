#if DEBUG
import ARKit
import OSLog
import SceneKit
import SwiftUI

/// A bench test for the green reader, not the feature itself: scan a patch of
/// ground with the LiDAR sensor and read back its slope, so the reading can
/// be checked against a surface whose slope is known. Debug builds only.
struct GreenScanTestView: View {
    @StateObject private var scanner = GreenScanSession()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GreenScanCameraView(session: scanner.session)
                .ignoresSafeArea()

            // Where the patch is centred.
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white)
                .shadow(radius: 2)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                panel
            }
        }
        .onAppear { scanner.start() }
        .onDisappear { scanner.stop() }
        .statusBarHidden()
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close")

            Text(scanner.statusText)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let reading = scanner.latest {
                latestReading(reading)
            } else {
                Text("Sweep the phone slowly over the patch, about waist height, until the point count stops climbing. Aim the cross at the middle of it and tap Measure.")
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if scanner.readings.count > 1 {
                repeatability
            }

            logFields

            Picker("Patch size", selection: $scanner.radiusMeters) {
                ForEach(GreenScanSession.radiusChoices, id: \.self) { radius in
                    Text("\(GreenScanReading.oneDecimal(radius * 2)) m patch").tag(radius)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Button {
                    scanner.measure()
                } label: {
                    HStack {
                        Text("Measure")
                        Spacer(minLength: 12)
                        Image(systemName: "scope")
                    }
                }
                .buttonStyle(BookStampButtonStyle())
                .disabled(!scanner.isSupported)

                Button("Reset") { scanner.reset() }
                    .buttonStyle(BookStampButtonStyle(prominent: false))
                    .frame(width: 110)
            }

            levelCheck
        }
        .padding(18)
        .foregroundStyle(Book.ink)
        .background(Book.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    /// The reference: the phone laid flat on the floor reads the true tilt
    /// there, in the same axes as the scan.
    private var levelCheck: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookHairline()
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Button(scanner.isHalfwayThroughLevel ? "Level: second half" : "Check floor level") {
                    scanner.captureLevel()
                }
                .font(.subheadline.weight(.semibold))
                .tint(Book.stamp)
                .disabled(!scanner.isSupported || scanner.isSamplingLevel)
                Spacer(minLength: 0)
            }
            .padding(.top, 6)
            Text(scanner.levelMessage)
                .font(.caption)
                .foregroundStyle(Book.pencil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// What gets written beside each reading in the console log.
    private var logFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("Where (e.g. kitchen floor)", text: $scanner.label)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                TextField("True %", text: $scanner.knownSlopeText)
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.done)
                    .frame(width: 76)
            }
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)

        }
    }

    private func latestReading(_ reading: GreenScanReading) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(GreenScanReading.oneDecimal(reading.slopePercent))%")
                    .font(.system(size: 52, weight: .bold).width(.condensed))
                    .monospacedDigit()
                Text("\(GreenScanReading.oneDecimal(reading.slopeDegrees))° · \(reading.fallDescription)")
                    .font(.subheadline.weight(.medium))
                Text("Noise ±\(GreenScanReading.oneDecimal(reading.noiseMillimeters)) mm · \(reading.pointCount) points · \(GreenScanReading.oneDecimal(reading.spanMeters)) m across")
                    .font(.caption)
                    .foregroundStyle(Book.pencil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            // Points downhill, with the top of the phone as "ahead".
            Image(systemName: "arrow.up")
                .font(.system(size: 34, weight: .bold))
                .rotationEffect(.radians(reading.fallAngleFromAhead))
                .frame(width: 64, height: 64)
                .background(Book.wash, in: Circle())
                .accessibilityLabel(reading.fallDescription)
        }
    }

    private var repeatability: some View {
        let slopes: [Double] = scanner.readings.map(\.slopePercent)
        let total: Double = slopes.reduce(0, +)
        let mean: Double = total / Double(slopes.count)
        let highest: Double = slopes.max() ?? 0
        let lowest: Double = slopes.min() ?? 0
        let spread: Double = highest - lowest
        return VStack(alignment: .leading, spacing: 4) {
            BookHairline()
            Text("\(slopes.count) readings · average \(GreenScanReading.oneDecimal(mean))% · spread \(GreenScanReading.oneDecimal(spread))%")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)
            Text(slopes.map { "\(GreenScanReading.oneDecimal($0))%" }.joined(separator: "  "))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Book.pencil)
                .lineLimit(2)
        }
    }
}

/// One slope reading from a scanned patch.
struct GreenScanReading: Equatable {
    /// Rise over run of the best-fit plane, as a percentage.
    let slopePercent: Double
    /// Clockwise angle from "straight ahead of the phone" to the downhill direction.
    let fallAngleFromAhead: Double
    /// How far the scanned points sit from the fitted plane (RMS).
    let noiseMillimeters: Double
    let pointCount: Int
    /// Width of the ground actually covered by the points used.
    let spanMeters: Double

    var slopeDegrees: Double {
        let radians: Double = atan(slopePercent / 100)
        return radians * 180 / Double.pi
    }

    var fallDescription: String {
        guard slopePercent >= 0.3 else { return "level" }
        let raw: Double = fallAngleFromAhead * 180 / Double.pi + 360
        let degrees: Double = raw.truncatingRemainder(dividingBy: 360)
        switch degrees {
        case 337.5..., ..<22.5: return "falls away from you"
        case 22.5..<67.5: return "falls away and right"
        case 67.5..<112.5: return "falls to the right"
        case 112.5..<157.5: return "falls towards you and right"
        case 157.5..<202.5: return "falls towards you"
        case 202.5..<247.5: return "falls towards you and left"
        case 247.5..<292.5: return "falls to the left"
        default: return "falls away and left"
        }
    }

    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

/// The arithmetic, kept apart from ARKit so it can be tested: fit a plane to
/// ground points and read the slope off it.
enum GreenScanMath {
    struct Fit: Equatable {
        /// Height change per metre along x and along z.
        let gradientX: Double
        let gradientZ: Double
        let rmsResidualMeters: Double
        let pointCount: Int
        let spanMeters: Double
        /// Height of the fitted plane at the middle of the points used.
        let groundHeight: Double

        var slopePercent: Double {
            let squaredGradient: Double = gradientX * gradientX + gradientZ * gradientZ
            return squaredGradient.squareRoot() * 100
        }
    }

    /// Least-squares plane `y = a·x + b·z + c` through the points, fitted
    /// twice: once through everything near the median height, then again
    /// without the points that sit off the first plane (grass tips, a shoe,
    /// the edge of a kerb).
    static func fitGround(_ points: [SIMD3<Float>], outlierMeters: Double = 0.03) -> Fit? {
        guard points.count >= 50 else { return nil }
        let heights: [Double] = points.map { Double($0.y) }.sorted()
        let median: Double = heights[heights.count / 2]
        var kept: [SIMD3<Float>] = points.filter { point in
            let height = Double(point.y)
            return abs(height - median) < 0.25
        }
        guard var fit = plane(through: kept) else { return nil }

        for _ in 0..<2 {
            let current = fit
            let trimmed = kept.filter { abs(current.residual(at: $0)) < outlierMeters }
            guard trimmed.count >= 50, let refit = plane(through: trimmed) else { break }
            kept = trimmed
            fit = refit
        }

        var squared: Double = 0
        var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
        var minZ = Double.greatestFiniteMagnitude, maxZ = -Double.greatestFiniteMagnitude
        for point in kept {
            let residual: Double = fit.residual(at: point)
            squared += residual * residual
            let x = Double(point.x)
            let z = Double(point.z)
            minX = min(minX, x)
            maxX = max(maxX, x)
            minZ = min(minZ, z)
            maxZ = max(maxZ, z)
        }
        let spanX: Double = maxX - minX
        let spanZ: Double = maxZ - minZ
        let span: Double = max(spanX, spanZ)
        return Fit(
            gradientX: fit.a,
            gradientZ: fit.b,
            rmsResidualMeters: (squared / Double(kept.count)).squareRoot(),
            pointCount: kept.count,
            spanMeters: span,
            groundHeight: fit.c
        )
    }

    /// Whether a fit is a clean read of one surface. Points scattered more
    /// than a few millimetres off the plane, or too few of them for the patch,
    /// mean something other than open ground was in it (furniture, a wall, a
    /// step), and the slope it gives is meaningless.
    static func isTrustworthy(_ fit: Fit, patchRadiusMeters: Double) -> Bool {
        let area: Double = Double.pi * patchRadiusMeters * patchRadiusMeters
        let density: Double = Double(fit.pointCount) / area
        return fit.rmsResidualMeters <= 0.004 && density >= 300
    }

    /// Clockwise angle from `ahead` (a horizontal direction, x and z) to the
    /// downhill direction of the fitted plane. ARKit's axes: y up, and with
    /// -z ahead, +x is to the right.
    static func fallAngle(gradientX: Double, gradientZ: Double, aheadX: Double, aheadZ: Double) -> Double {
        let downhillX: Double = -gradientX
        let downhillZ: Double = -gradientZ
        let rightX: Double = -aheadZ
        let rightZ: Double = aheadX
        let alongAhead: Double = downhillX * aheadX + downhillZ * aheadZ
        let alongRight: Double = downhillX * rightX + downhillZ * rightZ
        return atan2(alongRight, alongAhead)
    }

    private struct Plane {
        let a: Double, b: Double, c: Double
        let meanX: Double, meanZ: Double

        func residual(at point: SIMD3<Float>) -> Double {
            let dx: Double = Double(point.x) - meanX
            let dz: Double = Double(point.z) - meanZ
            let planeHeight: Double = a * dx + b * dz + c
            return Double(point.y) - planeHeight
        }
    }

    private static func plane(through points: [SIMD3<Float>]) -> Plane? {
        guard points.count >= 3 else { return nil }
        let n = Double(points.count)
        var sumX: Double = 0, sumY: Double = 0, sumZ: Double = 0
        for point in points {
            sumX += Double(point.x)
            sumY += Double(point.y)
            sumZ += Double(point.z)
        }
        let meanX: Double = sumX / n
        let meanY: Double = sumY / n
        let meanZ: Double = sumZ / n
        var sxx: Double = 0, szz: Double = 0, sxz: Double = 0, sxy: Double = 0, szy: Double = 0
        for point in points {
            let x: Double = Double(point.x) - meanX
            let y: Double = Double(point.y) - meanY
            let z: Double = Double(point.z) - meanZ
            sxx += x * x
            szz += z * z
            sxz += x * z
            sxy += x * y
            szy += z * y
        }
        let determinant: Double = sxx * szz - sxz * sxz
        guard abs(determinant) > 1e-9 else { return nil }
        let a: Double = (sxy * szz - szy * sxz) / determinant
        let b: Double = (szy * sxx - sxy * sxz) / determinant
        return Plane(a: a, b: b, c: meanY, meanX: meanX, meanZ: meanZ)
    }
}

/// The floor's true tilt at one spot, from laying the phone flat on it twice,
/// half a turn apart. Anything fixed to the phone (the camera bump it rests
/// on, its tilt sensor's own offset) points the opposite way the second time
/// and cancels in the average.
struct GreenScanLevel: Equatable {
    let gradientX: Double
    let gradientZ: Double
    /// Half the difference between the two placements: the part that came
    /// from the phone, not the floor.
    let phoneOffsetPercent: Double

    var slopePercent: Double {
        let squared: Double = gradientX * gradientX + gradientZ * gradientZ
        return squared.squareRoot() * 100
    }

    static func combining(
        first: (gradientX: Double, gradientZ: Double),
        second: (gradientX: Double, gradientZ: Double)
    ) -> GreenScanLevel {
        let halfDX: Double = (first.gradientX - second.gradientX) / 2
        let halfDZ: Double = (first.gradientZ - second.gradientZ) / 2
        let offsetSquared: Double = halfDX * halfDX + halfDZ * halfDZ
        return GreenScanLevel(
            gradientX: (first.gradientX + second.gradientX) / 2,
            gradientZ: (first.gradientZ + second.gradientZ) / 2,
            phoneOffsetPercent: offsetSquared.squareRoot() * 100
        )
    }
}

/// Every reading, written to the Xcode console as a CSV row so a run of them
/// can be copied out and compared. Nothing is saved on the phone.
enum GreenScanLog {
    static let logger = Logger(subsystem: "com.ghtech.swingpal", category: "GreenScan")

    struct Entry {
        let date: Date
        let label: String
        let knownSlopePercent: Double?
        let patchMeters: Double
        let slopePercent: Double
        /// Height change per metre along the session's x and z axes. These
        /// axes are fixed for one scanning session, so the same patch should
        /// give the same pair whichever side it's measured from.
        let gradientX: Double
        let gradientZ: Double
        let fallFromAheadDegrees: Double
        let noiseMillimeters: Double
        let pointCount: Int
        let spanMeters: Double
        let cameraHeightMeters: Double
        let distanceToCentreMeters: Double
        let meshPointCount: Int
        let tracking: String
        /// Which way the phone was facing (session axes) and how steeply it
        /// looked down (90 is straight down), to tell a real slope from one
        /// that follows the viewer around.
        let aheadX: Double
        let aheadZ: Double
        let pitchDegrees: Double
        let isTrustworthy: Bool
        /// Points left out for being where the person is standing.
        let pointsNearViewer: Int
        /// The floor's true tilt from the level check, in the same axes, and
        /// how far this reading's tilt is from it (as a slope percentage).
        let levelGradientX: Double?
        let levelGradientZ: Double?
    }

    static let header = "time,label,true_slope_pct,patch_m,slope_pct,error_pct,gradient_x,gradient_z,fall_from_ahead_deg,noise_mm,points,span_m,camera_height_m,distance_to_centre_m,mesh_points,tracking,ahead_x,ahead_z,pitch_deg,quality,near_viewer_points,level_gx,level_gz,error_vs_level_pct,device,os"

    static func logLevel(label: String, level: GreenScanLevel, turnDegrees: Double) {
        let fields: [String] = [
            "LEVEL",
            ISO8601DateFormatter().string(from: Date()),
            "\"\(label.trimmingCharacters(in: .whitespacesAndNewlines))\"",
            "slope_pct=" + String(format: "%.2f", level.slopePercent),
            "gradient_x=" + String(format: "%.4f", level.gradientX),
            "gradient_z=" + String(format: "%.4f", level.gradientZ),
            "phone_offset_pct=" + String(format: "%.2f", level.phoneOffsetPercent),
            "turn_deg=" + String(format: "%.0f", turnDegrees)
        ]
        let line = fields.joined(separator: ",")
        logger.notice("\(line, privacy: .public)")
    }

    /// Distance between the scanned tilt and the level check's, direction
    /// included, as a slope percentage.
    static func vectorError(_ entry: Entry) -> Double? {
        guard let levelX = entry.levelGradientX, let levelZ = entry.levelGradientZ else { return nil }
        let dx: Double = entry.gradientX - levelX
        let dz: Double = entry.gradientZ - levelZ
        let squared: Double = dx * dx + dz * dz
        return squared.squareRoot() * 100
    }

    static func row(for entry: Entry) -> String {
        func number(_ value: Double, _ places: Int) -> String {
            String(format: "%.\(places)f", value)
        }
        let cleanLabel = entry.label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
        var known = ""
        var error = ""
        if let knownSlope = entry.knownSlopePercent {
            known = number(knownSlope, 2)
            error = number(entry.slopePercent - knownSlope, 2)
        }
        let fields: [String] = [
            ISO8601DateFormatter().string(from: entry.date),
            "\"\(cleanLabel)\"",
            known,
            number(entry.patchMeters, 1),
            number(entry.slopePercent, 2),
            error,
            number(entry.gradientX, 4),
            number(entry.gradientZ, 4),
            number(entry.fallFromAheadDegrees, 0),
            number(entry.noiseMillimeters, 1),
            "\(entry.pointCount)",
            number(entry.spanMeters, 2),
            number(entry.cameraHeightMeters, 2),
            number(entry.distanceToCentreMeters, 2),
            "\(entry.meshPointCount)",
            entry.tracking,
            number(entry.aheadX, 2),
            number(entry.aheadZ, 2),
            number(entry.pitchDegrees, 0),
            entry.isTrustworthy ? "ok" : "rejected",
            "\(entry.pointsNearViewer)",
            entry.levelGradientX.map { number($0, 4) } ?? "",
            entry.levelGradientZ.map { number($0, 4) } ?? "",
            vectorError(entry).map { number($0, 2) } ?? "",
            deviceModel,
            ProcessInfo.processInfo.operatingSystemVersionString
        ]
        return fields.joined(separator: ",")
    }

    private static var hasPrintedHeader = false

    /// Writes the reading to the console as one CSV row (with the column
    /// names once per launch). Nothing is saved on the phone.
    static func append(_ entry: Entry) {
        if !hasPrintedHeader {
            hasPrintedHeader = true
            logger.notice("\(header, privacy: .public)")
        }
        let line = row(for: entry)
        logger.notice("\(line, privacy: .public)")
    }

    static var deviceModel: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}

/// Runs the AR session and turns its surface mesh into readings.
@MainActor
final class GreenScanSession: NSObject, ObservableObject {
    static let radiusChoices: [Double] = [0.5, 1.0, 2.0]
    /// Scanned points this close to where the phone is held are the person
    /// holding it, not the ground.
    static let viewerExclusionMeters: Float = 0.5

    let session = ARSession()

    @Published var radiusMeters: Double = 1.0
    /// Written beside each reading in the log: where it was taken, and the
    /// surface's real slope if it's known.
    @Published var label = ""
    @Published var knownSlopeText = ""
    @Published private(set) var statusText = "Starting the camera…"
    @Published private(set) var readings: [GreenScanReading] = []
    @Published private(set) var isSupported = true

    var latest: GreenScanReading? { readings.last }

    // The level check: see `GreenScanLevel`.
    @Published private(set) var level: GreenScanLevel?
    @Published private(set) var levelMessage = "For a reference: lay the phone flat on the spot, screen up, and tap Check floor level."
    @Published private(set) var isSamplingLevel = false
    private var firstPlacement: (gradientX: Double, gradientZ: Double, yaw: Double)?
    var isHalfwayThroughLevel: Bool { firstPlacement != nil }

    private var statusTimer: Timer?

    func start() {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            isSupported = false
            statusText = "This device has no LiDAR sensor, so it can't scan a surface."
            return
        }
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        // Gravity-aligned: y is straight up, which is the level reference.
        configuration.worldAlignment = .gravity
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
    }

    func stop() {
        statusTimer?.invalidate()
        statusTimer = nil
        session.pause()
    }

    func reset() {
        GreenScanLog.logger.notice("RESET,level_cleared=\(self.level != nil, privacy: .public)")
        readings = []
        // A new session has new axes, so the old level reading means nothing in it.
        level = nil
        firstPlacement = nil
        levelMessage = "For a reference: lay the phone flat on the spot, screen up, and tap Check floor level."
        start()
    }

    /// Reads the phone's own tilt while it lies on the floor. Call twice,
    /// with the phone turned half a turn in between.
    func captureLevel() {
        guard isSupported, !isSamplingLevel else { return }
        isSamplingLevel = true
        levelMessage = "Hold still…"
        GreenScanLog.logger.notice("LEVEL,step=started,half=\(self.firstPlacement == nil ? 1 : 2, privacy: .public)")
        Task { @MainActor in
            // Let the tap's wobble die away, then average a second of readings.
            try? await Task.sleep(for: .milliseconds(1200))
            var sumX: Double = 0, sumZ: Double = 0
            var sumTopX: Double = 0, sumTopZ: Double = 0
            var samples = 0
            var wasFlat = true
            var framesSeen = 0
            var lowestUp: Double = 1
            for _ in 0..<25 {
                if let frame = self.session.currentFrame {
                    let transform = frame.camera.transform
                    // The camera's z axis comes straight out of the screen.
                    var nx = Double(transform.columns.2.x)
                    var ny = Double(transform.columns.2.y)
                    var nz = Double(transform.columns.2.z)
                    if ny < 0 {
                        nx = -nx
                        ny = -ny
                        nz = -nz
                    }
                    framesSeen += 1
                    lowestUp = min(lowestUp, ny)
                    if ny < 0.94 {
                        wasFlat = false
                    } else {
                        sumX += -nx / ny
                        sumZ += -nz / ny
                        sumTopX += Double(transform.columns.0.x)
                        sumTopZ += Double(transform.columns.0.z)
                        samples += 1
                    }
                }
                try? await Task.sleep(for: .milliseconds(40))
            }
            self.isSamplingLevel = false
            guard wasFlat, samples >= 10 else {
                self.levelMessage = "The phone wasn't lying flat. Lay it on the floor, screen up, and tap again."
                let tiltDegrees: Double = acos(max(-1, min(1, lowestUp))) * 180 / Double.pi
                GreenScanLog.logger.notice("LEVEL,step=failed,reason=not_flat,frames=\(framesSeen, privacy: .public),samples=\(samples, privacy: .public),max_tilt_deg=\(String(format: "%.1f", tiltDegrees), privacy: .public)")
                return
            }
            let gradientX: Double = sumX / Double(samples)
            let gradientZ: Double = sumZ / Double(samples)
            let yaw: Double = atan2(sumTopZ, sumTopX)
            GreenScanLog.logger.notice("LEVEL,step=captured,samples=\(samples, privacy: .public),gradient_x=\(String(format: "%.4f", gradientX), privacy: .public),gradient_z=\(String(format: "%.4f", gradientZ), privacy: .public),yaw_deg=\(String(format: "%.0f", yaw * 180 / Double.pi), privacy: .public)")

            guard let first = self.firstPlacement else {
                self.firstPlacement = (gradientX, gradientZ, yaw)
                self.levelMessage = "Got the first half. Now spin the phone half a turn on the same spot (top where the bottom was) and tap again."
                return
            }
            self.firstPlacement = nil
            var turn: Double = abs(yaw - first.yaw) * 180 / Double.pi
            if turn > 180 { turn = 360 - turn }
            guard turn >= 150 else {
                GreenScanLog.logger.notice("LEVEL,step=failed,reason=turn_too_small,turn_deg=\(String(format: "%.0f", turn), privacy: .public)")
                self.levelMessage = "That was only about \(Int(turn.rounded()))° of turn, so the two halves don't cancel. Start again and spin it a full half turn."
                return
            }
            let result = GreenScanLevel.combining(
                first: (first.gradientX, first.gradientZ),
                second: (gradientX, gradientZ)
            )
            self.level = result
            self.knownSlopeText = String(format: "%.2f", result.slopePercent)
            self.levelMessage = "Floor here is \(GreenScanReading.oneDecimal(result.slopePercent))% off level (the phone itself added \(GreenScanReading.oneDecimal(result.phoneOffsetPercent))%, now cancelled). Scan readings are compared with this until you Reset."
            GreenScanLog.logLevel(label: self.label, level: result, turnDegrees: turn)
        }
    }

    private func refreshStatus() {
        guard isSupported, let frame = session.currentFrame else { return }
        var count = 0
        for case let anchor as ARMeshAnchor in frame.anchors {
            count += anchor.geometry.vertices.count
        }
        switch frame.camera.trackingState {
        case .normal:
            statusText = count == 0 ? "Sweep the phone slowly over the ground…" : "\(count) surface points scanned"
        case .limited:
            statusText = "Tracking is limited — move more slowly, with more light."
        case .notAvailable:
            statusText = "Starting the camera…"
        }
    }

    func measure() {
        guard isSupported, let frame = session.currentFrame else { return }
        let camera = frame.camera.transform
        let position = SIMD3<Float>(camera.columns.3.x, camera.columns.3.y, camera.columns.3.z)
        // The camera looks along its own -z. Held nearly flat over the
        // ground that has almost no horizontal part, so fall back to the top
        // of the phone (the camera's +x when held upright).
        var ahead = SIMD2<Float>(-camera.columns.2.x, -camera.columns.2.z)
        if simd_length(ahead) < 0.3 {
            ahead = SIMD2<Float>(camera.columns.0.x, camera.columns.0.z)
        }
        guard simd_length(ahead) > 0.01 else { return }
        ahead = simd_normalize(ahead)

        // Centre the patch where the cross meets the ground.
        let standingAt = SIMD2<Float>(position.x, position.z)
        var centre: SIMD2<Float> = standingAt + ahead
        let query = frame.raycastQuery(from: CGPoint(x: 0.5, y: 0.5), allowing: .estimatedPlane, alignment: .any)
        if let hit = session.raycast(query).first {
            centre = SIMD2<Float>(hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.z)
        }

        let radius = Float(radiusMeters)
        var points: [SIMD3<Float>] = []
        var nearViewer = 0
        for case let anchor as ARMeshAnchor in frame.anchors {
            let vertices = anchor.geometry.vertices
            let base = vertices.buffer.contents().advanced(by: vertices.offset)
            for index in 0..<vertices.count {
                let raw = base.advanced(by: index * vertices.stride)
                    .assumingMemoryBound(to: (Float, Float, Float).self).pointee
                let world = anchor.transform * SIMD4<Float>(raw.0, raw.1, raw.2, 1)
                let onGround = SIMD2<Float>(world.x, world.z)
                guard simd_length(onGround - centre) <= radius else { continue }
                // Whoever is holding the phone is standing in the scan: leave
                // out their feet and legs, which would tilt the fit.
                if simd_length(onGround - standingAt) < Self.viewerExclusionMeters {
                    nearViewer += 1
                    continue
                }
                points.append(SIMD3<Float>(world.x, world.y, world.z))
            }
        }

        guard let fit = GreenScanMath.fitGround(points) else {
            statusText = "Not enough of the surface scanned there yet — sweep over it and try again."
            GreenScanLog.logger.notice("No reading: \(points.count) points in a \(self.radiusMeters * 2) m patch")
            return
        }
        let fallAngle: Double = GreenScanMath.fallAngle(
            gradientX: fit.gradientX,
            gradientZ: fit.gradientZ,
            aheadX: Double(ahead.x),
            aheadZ: Double(ahead.y)
        )
        var meshPoints = 0
        for case let anchor as ARMeshAnchor in frame.anchors {
            meshPoints += anchor.geometry.vertices.count
        }
        let trackingName: String
        switch frame.camera.trackingState {
        case .normal: trackingName = "normal"
        case .limited: trackingName = "limited"
        case .notAvailable: trackingName = "unavailable"
        }
        let lookDown: Double = Double(camera.columns.2.y)
        let pitch: Double = asin(max(-1, min(1, lookDown))) * 180 / Double.pi
        let trustworthy = GreenScanMath.isTrustworthy(fit, patchRadiusMeters: radiusMeters)
        GreenScanLog.append(GreenScanLog.Entry(
            date: Date(),
            label: label,
            knownSlopePercent: Double(knownSlopeText.replacingOccurrences(of: ",", with: ".")),
            patchMeters: radiusMeters * 2,
            slopePercent: fit.slopePercent,
            gradientX: fit.gradientX,
            gradientZ: fit.gradientZ,
            fallFromAheadDegrees: fallAngle * 180 / Double.pi,
            noiseMillimeters: fit.rmsResidualMeters * 1000,
            pointCount: fit.pointCount,
            spanMeters: fit.spanMeters,
            cameraHeightMeters: Double(position.y) - fit.groundHeight,
            distanceToCentreMeters: Double(simd_length(centre - standingAt)),
            meshPointCount: meshPoints,
            tracking: trackingName,
            aheadX: Double(ahead.x),
            aheadZ: Double(ahead.y),
            pitchDegrees: pitch,
            isTrustworthy: trustworthy,
            pointsNearViewer: nearViewer,
            levelGradientX: level?.gradientX,
            levelGradientZ: level?.gradientZ
        ))
        guard trustworthy else {
            statusText = "Not a clean read — something other than open ground is in the patch. Move it clear and try again."
            return
        }
        refreshStatus()
        readings.append(GreenScanReading(
            slopePercent: fit.slopePercent,
            fallAngleFromAhead: fallAngle,
            noiseMillimeters: fit.rmsResidualMeters * 1000,
            pointCount: fit.pointCount,
            spanMeters: fit.spanMeters
        ))
    }
}

private struct GreenScanCameraView: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
#endif
