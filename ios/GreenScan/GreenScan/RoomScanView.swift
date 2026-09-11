import RoomPlan
import SwiftUI

/// 라이다(RoomPlan)로 방을 스캔해서 SpaceInputView의 치수 입력값을 자동으로
/// 채워주는 화면. docs/lidar-space-capture-proposal.md(2026-09-12)에서 정리한
/// 설계를 그대로 구현한다.
///
/// RoomPlan은 벽을 "내벽/외벽(외기 접촉 여부)"으로 자동 분류하지 못한다(실내
/// 스캔만으로는 원리적으로 판별 불가) — 그래서 스캔이 끝나면 감지된 벽
/// 목록을 평면도 대신 리스트로 보여주고, 사용자가 직접 "외기 접촉" 벽을
/// 골라야 wall.exterior_total_area_m2를 만들 수 있다.
///
/// 실기기(라이다 탑재 iPhone Pro/iPad Pro) 전용 — 시뮬레이터와 라이다 없는
/// 기기에서는 RoomCaptureSession.isSupported가 false라 안내 문구만 보여준다.
///
/// 백엔드 연동 주의: InputSource enum에 "lidar"가 아직 없어(예약값만,
/// api-spec.md 2.4) 계산 API에 그대로 보낼 수는 없다 — 지금은 DiagnosisFlowState의
/// 치수 필드만 채우고, 실제 제출 시 input_source는 BE가 lidar를 받아주기
/// 전까지 "user_corrected"로 보내야 한다(제출 화면에서 처리할 몫).
struct RoomScanView: View {
    @Environment(DiagnosisFlowState.self) private var flow
    @Environment(\.dismiss) private var dismiss

    @State private var controller = RoomScanController()
    @State private var stage: Stage = .intro

    private enum Stage {
        case intro
        case scanning
        case reviewing(RoomMeasurement)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !RoomCaptureSession.isSupported {
                    unsupportedNotice
                } else {
                    switch stage {
                    case .intro:
                        introView
                    case .scanning:
                        scanningView
                    case .reviewing(let measurement):
                        ReviewView(measurement: measurement) { applied in
                            apply(applied)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("라이다로 측정하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .onAppear {
            controller.onCaptureFinished = { room in
                stage = .reviewing(RoomMeasurement(room: room))
            }
        }
    }

    private var unsupportedNotice: some View {
        VStack(spacing: 12) {
            Image(systemName: "lidar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("이 기기는 라이다를 지원하지 않아요.")
                .font(.system(size: 15, weight: .semibold))
            Text("iPhone 12 Pro 이상 Pro 라인 또는 iPad Pro(라이다 탑재 모델)에서 사용할 수 있어요.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var introView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arkit")
                .font(.system(size: 48))
                .foregroundStyle(Color.brand500)
            Text("방을 천천히 한 바퀴 돌면서\n벽과 창문을 스캔해요")
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("스캔이 끝나면 감지된 벽 중에서 외기와 접한 벽을 직접 골라야 해요.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                stage = .scanning
                controller.start()
            } label: {
                Text("스캔 시작")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.brand500)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 21)
            .padding(.bottom, 24)
        }
    }

    private var scanningView: some View {
        ZStack(alignment: .bottom) {
            RoomCaptureRepresentable(controller: controller)
                .ignoresSafeArea()

            Button {
                controller.stop()
            } label: {
                Text("스캔 완료")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.brand500)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 21)
            .padding(.bottom, 32)
        }
    }

    private func apply(_ measurement: RoomMeasurement) {
        flow.width = measurement.formattedWidth
        flow.depth = measurement.formattedDepth
        flow.height = measurement.formattedHeight
        flow.floorArea = measurement.formattedFloorArea
        flow.windowArea = measurement.formattedWindowArea
        flow.wallArea = measurement.formattedSelectedWallArea
    }
}

/// RoomCaptureSession 실행/정지를 담당하고, RoomPlan 자체 리뷰 UI가 끝나면
/// 최종 CapturedRoom을 들고 있는다.
// SwiftUI가 이 컨트롤러의 프로퍼티 변화로 다시 그릴 필요가 없어서(결과는
// onCaptureFinished 클로저로 직접 전달) @Observable을 안 붙인다 — NSObject를
// 상속해야 하는(RoomCaptureViewDelegate 요구사항) 클래스에 @Observable을
// 같이 쓰면 NSCoding 컴파일 에러가 났다.
final class RoomScanController: NSObject, RoomCaptureViewDelegate, NSCoding {
    weak var captureView: RoomCaptureView?
    var onCaptureFinished: ((CapturedRoom) -> Void)?

    override init() {
        super.init()
    }

    // RoomCaptureViewDelegate 채택 시 이 SDK 버전에서 왜인지 NSCoding까지
    // 요구해서(디코딩/인코딩을 실제로 쓰지 않음에도) 최소 스텁만 채운다.
    required init?(coder: NSCoder) { return nil }
    func encode(with coder: NSCoder) {}

    func start() {
        guard let captureView else { return }
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    func stop() {
        captureView?.captureSession.stop()
    }

    // RoomPlan이 자체적으로 처리(RoomBuilder)한 결과를 다시 자기 리뷰 UI로
    // 보여줄지 묻는다 — 우리는 항상 보여주게 둔다(사용자가 RoomPlan 기본
    // 편집 화면에서 벽 위치를 직접 다듬을 수 있게).
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: (any Error)?) -> Bool {
        true
    }

    // RoomPlan 리뷰 화면에서 사용자가 "Done"을 누르면 최종 결과가 여기로 온다.
    func captureView(didPresent processedResult: CapturedRoom, error: (any Error)?) {
        onCaptureFinished?(processedResult)
    }
}

/// CapturedRoom을 SpaceInputView가 쓰는 값(가로/세로/높이/바닥면적/창호면적/
/// 벽체면적)으로 정리한다. 벽의 "외기 접촉" 여부는 라이다가 못 판별하므로
/// 사용자가 고르고(walls[].isExterior), 창호 면적은 백엔드 팀과 합의한 대로
/// "선택한 외벽에 속한 창문만" 합산한다 — 벽 면적에서 미리 빼지 않는다
/// (순면적 차감은 서버의 check_wall_net_area()가 한다).
@Observable
final class RoomMeasurement {
    struct WallItem: Identifiable {
        let id: UUID
        let areaM2: Double
        var isExterior = false
    }

    struct WindowItem: Identifiable {
        let id: UUID
        let areaM2: Double
        let wallId: UUID?
    }

    let widthM: Double
    let depthM: Double
    let heightM: Double
    let floorAreaM2: Double
    var walls: [WallItem]
    var windows: [WindowItem]

    init(room: CapturedRoom) {
        if let floor = room.floors.first {
            widthM = Double(floor.dimensions.x)
            depthM = Double(floor.dimensions.z)
            floorAreaM2 = widthM * depthM
        } else {
            // 바닥면이 안 잡힌 경우(드묾) 벽 위치들의 바운딩 박스로 대략 추정한다.
            let positions = room.walls.map { $0.transform.columns.3 }
            let xs = positions.map { $0.x }
            let zs = positions.map { $0.z }
            widthM = Double((xs.max() ?? 0) - (xs.min() ?? 0))
            depthM = Double((zs.max() ?? 0) - (zs.min() ?? 0))
            floorAreaM2 = widthM * depthM
        }

        heightM = room.walls.isEmpty
            ? 0
            : Double(room.walls.reduce(Float(0)) { $0 + $1.dimensions.y }) / Double(room.walls.count)

        walls = room.walls.map { wall in
            WallItem(id: wall.identifier, areaM2: Double(wall.dimensions.x * wall.dimensions.y))
        }
        windows = room.windows.map { window in
            WindowItem(
                id: window.identifier,
                areaM2: Double(window.dimensions.x * window.dimensions.y),
                wallId: window.parentIdentifier
            )
        }
    }

    var selectedWallAreaM2: Double {
        walls.filter(\.isExterior).reduce(0) { $0 + $1.areaM2 }
    }

    /// 선택한 외벽에 속한 창문만 합산 — BE 합의(2026-09-12): 창문 면적은 벽
    /// 면적에서 미리 빼지 않고 그대로 보낸다.
    var selectedWindowAreaM2: Double {
        let exteriorWallIds = Set(walls.filter(\.isExterior).map(\.id))
        return windows
            .filter { $0.wallId.map(exteriorWallIds.contains) ?? false }
            .reduce(0) { $0 + $1.areaM2 }
    }

    var formattedWidth: String { Self.format(widthM) }
    var formattedDepth: String { Self.format(depthM) }
    var formattedHeight: String { Self.format(heightM) }
    var formattedFloorArea: String { Self.format(floorAreaM2) }
    var formattedWindowArea: String { Self.format(selectedWindowAreaM2) }
    var formattedSelectedWallArea: String { Self.format(selectedWallAreaM2) }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

/// 스캔 결과 리뷰 화면: 치수 확인, 외기 접촉 벽 선택, 집계된 면적 표시.
private struct ReviewView: View {
    @Bindable var measurement: RoomMeasurement
    let onApply: (RoomMeasurement) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dimensionsSection
                    wallsSection
                    summarySection
                }
                .padding(21)
                .padding(.bottom, 100)
            }
            applyButton
        }
    }

    private var dimensionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("측정된 치수").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
            HStack(spacing: 8) {
                metric("가로", "\(measurement.formattedWidth) m")
                metric("세로", "\(measurement.formattedDepth) m")
                metric("높이", "\(measurement.formattedHeight) m")
            }
            Text("측정이 잘못됐으면 다음 화면(공간 치수 입력)에서 직접 고칠 수 있어요.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var wallsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("외기에 접한 벽을 선택하세요").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
            Text("라이다는 실내 스캔만으로 어떤 벽이 바깥과 닿아있는지 구분하지 못해요 — 직접 골라주세요.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if measurement.walls.isEmpty {
                Text("감지된 벽이 없어요. 스캔을 다시 시도해주세요.")
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }

            ForEach(Array(measurement.walls.enumerated()), id: \.element.id) { index, wall in
                Button {
                    measurement.walls[index].isExterior.toggle()
                } label: {
                    HStack {
                        Image(systemName: wall.isExterior ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(wall.isExterior ? Color.brand500 : Color(hex: "535353").opacity(0.4))
                        Text("벽 \(index + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "535353"))
                        Spacer()
                        Text(String(format: "%.2f m²", wall.areaM2))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(wall.isExterior ? Color.brand50 : Color(hex: "BEBEBE").opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("계산에 쓰일 값").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
            metricRow("외기 접촉 벽체 합산면적(창문 포함)", "\(measurement.formattedSelectedWallArea) m²")
            metricRow("선택한 벽에 속한 창호 합산면적", "\(measurement.formattedWindowArea) m²")
            metricRow("바닥면적(참고용)", "\(measurement.formattedFloorArea) m²")
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(hex: "BEBEBE").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "176b52"))
        }
    }

    private var applyButton: some View {
        Button {
            onApply(measurement)
        } label: {
            Text("이 값으로 채우기")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(measurement.walls.contains(where: \.isExterior) ? Color.brand500 : Color(hex: "535353").opacity(0.3))
                .clipShape(Capsule())
        }
        .disabled(!measurement.walls.contains(where: \.isExterior))
        .padding(.horizontal, 21)
        .padding(.vertical, 16)
    }
}

private struct RoomCaptureRepresentable: UIViewRepresentable {
    let controller: RoomScanController

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.delegate = controller
        controller.captureView = view
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}

#Preview {
    RoomScanView().environment(DiagnosisFlowState())
}
