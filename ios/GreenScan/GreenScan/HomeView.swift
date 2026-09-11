import SwiftUI

private let fabMenuItems: [(key: String, label: String)] = [
    ("terms", "이용약관"),
    ("support", "고객센터"),
]

/// "최근 분석한 건물" 섹션의 로딩 상태. 목업이었던 이전 버전과 달리, 이제는
/// 실제 GET /api/v1/diagnoses 응답을 그대로 반영한다 — 로그인하지 않았거나
/// (오프라인 데모 계정 포함) 진단 이력이 없으면 빈 상태를 정직하게 보여준다.
private enum RecentBuildingsState {
    case notLoggedIn
    case loading
    case loaded([RecentBuilding])
    case failed
}

/// 웹 버전 frontend/src/features/home/HomePage.tsx의 포팅.
/// 웹의 핵심 인터랙션 두 가지를 SwiftUI 방식으로 그대로 옮겼다:
/// 1) 히어로 배너는 고정 배경으로 깔려 있고, "최근 분석한 건물" 시트가 그
///    위를 스크롤로 덮으며 올라와 검색바 바로 아래(pinned section header)에서
///    멈춘 뒤로는 카드 리스트만 평범히 스크롤된다 (웹의 absolute 스페이서 +
///    position:sticky 트릭 → GeometryReader 높이 계산 + LazyVStack
///    pinnedViews 로 대응).
/// 2) 우하단 + 버튼을 누르면 이용약관/고객센터 원이 위로 갈수록 옅어지는
///    색으로 순차 등장하는 스피드다이얼 메뉴.
struct HomeView: View {
    @Environment(AuthState.self) private var auth
    @Environment(DiagnosisNavigationPath.self) private var diagnosisNavigationPath
    @Environment(DiagnosisFlowState.self) private var diagnosisFlow
    @State private var fabOpen = false
    @State private var recentState: RecentBuildingsState = .notLoggedIn
    @State private var navigateToSurvey = false
    // 진단 플로우(홈→AI진단→건물유형→공간입력)를 안 거치고 라이다 스캔만 바로
    // 테스트하는 버튼(PM 요청, 2026-09-12: "라이다 테스트는 그대로 냅둬줘").
    // 정식 진입점은 SpaceInputView의 "라이다로 측정하기"고, 이 버튼도 같은
    // 앱 전역 공유 DiagnosisFlowState(GreenScanApp.swift)에 그대로 저장한다 —
    // 임시 화면일 뿐 저장되는 값 자체는 진짜다.
    @State private var showLidarTest = false

    var body: some View {
        NavigationStack(path: Bindable(diagnosisNavigationPath).path) {
            VStack(spacing: 0) {
                searchBar

                GeometryReader { geo in
                    // PM 피드백(2026-09-12): 히어로가 검색바를 가리고 "최근 분석한
                    // 건물" 섹션과도 겹쳐 보인다는 리포트가 있어 웹 원본 비율
                    // (359:190, 배너가 화면의 절반 가까이 차지)보다 확실히 작게
                    // 줄였다. 겹침 재발을 막기 위해 .frame 뒤에 .clipped()도 붙여서
                    // 오버레이 콘텐츠가 프레임 밖으로 새는 걸 강제로 차단한다.
                    let heroHeight = (geo.size.width - 32) * 160 / 359

                    ZStack(alignment: .top) {
                        // 이전 수정(Button + navigationDestination(isPresented:)로
                        // 교체)도 안 먹혔던 진짜 이유: ZStack 안에서 ScrollView가
                        // 히어로 Button보다 "뒤에" 선언돼 있었다 — SwiftUI ZStack은
                        // 나중에 선언된 자식을 위에(앞에) 그리므로, 실제로는
                        // ScrollView가 히어로 영역 위에 깔려 있었다. 투명 스페이서에
                        // allowsHitTesting(false)를 줘도 ScrollView 컨테이너 자체가
                        // 스크롤 제스처 인식을 위해 그 영역의 터치를 먼저 가져가서,
                        // 탭 다운 시 버튼이 눌리는 것처럼 보이긴 해도(하이라이트) 탭
                        // 업 시점에 제스처 우선권을 ScrollView가 가져가 버려 실제
                        // 액션은 실행되지 않았다(2026-09-12, 실기기 재확인: "누르면
                        // 반응하는데 화면이 안 바뀜"). ScrollView를 먼저 선언해서
                        // 뒤로 보내고 히어로 Button을 마지막에 선언해 확실히 맨
                        // 앞(위)에 오도록 순서를 뒤집었다.
                        ScrollView {
                            VStack(spacing: 0) {
                                // 히어로와 같은 높이의 투명 스페이서 — 실제 히어로는
                                // 이제 이 ZStack의 맨 앞(뒤에 따로 선언)에 있으므로
                                // 여기는 순수하게 레이아웃 공간만 차지한다.
                                Color.clear
                                    .frame(height: heroHeight)
                                    .allowsHitTesting(false)

                                // 헤더는 pinnedViews로 검색바 바로 아래에 고정되고, 카드는 그
                                // 밑에서 평범하게 스크롤된다(웹의 position:sticky와 동일한
                                // 효과). 알려진 제약: 헤더가 고정되는 첫 순간 히어로가 한 프레임
                                // 살짝 비치는 시각적 버그가 남아있다 — 스크롤 자체와 카드 목록
                                // 동작에는 영향 없음.
                                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                    Section {
                                        recentBuildingsContent
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                            .padding(.bottom, 112)
                                            .background(Color(.systemBackground))
                                    } header: {
                                        recentHeader
                                    }
                                }
                            }
                        }

                        Button {
                            navigateToSurvey = true
                        } label: {
                            heroBanner(height: heroHeight)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .frame(height: heroHeight)
                    }
                }
            }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                fab
            }
            .overlay(alignment: .bottomLeading) {
                Button {
                    showLidarTest = true
                } label: {
                    Text("🔬 라이다 테스트")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                }
                .padding(.leading, 16)
                .padding(.bottom, 96)
            }
            .fullScreenCover(isPresented: $showLidarTest) {
                RoomScanView().environment(diagnosisFlow)
            }
            .navigationDestination(isPresented: $navigateToSurvey) {
                // PM 지시(2026-09-12): AI 분석하기 전에 5단계 사전 설문을 먼저
                // 거치게 함 — SurveyView가 끝나면(5단계 "AI 분석하기" 버튼)
                // 그 안에서 AiDiagnosisView로 이어간다.
                SurveyView()
            }
        }
        .task(id: auth.sessionToken) {
            await loadRecentBuildings()
        }
    }

    @ViewBuilder
    private var recentBuildingsContent: some View {
        switch recentState {
        case .notLoggedIn:
            emptyState(
                message: auth.isLoggedIn
                    ? "오프라인 데모 계정은 최근 분석 내역을 불러올 수 없어요."
                    : "로그인하면 최근 분석한 건물을 볼 수 있어요."
            )
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        case .failed:
            emptyState(message: "최근 분석 내역을 불러오지 못했어요.")
        case .loaded(let buildings) where buildings.isEmpty:
            emptyState(message: "아직 분석한 건물이 없어요. AI 진단을 시작해보세요.")
        case .loaded(let buildings):
            VStack(spacing: 16) {
                ForEach(buildings) { building in
                    RecentBuildingCard(building: building)
                }
            }
        }
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    @MainActor
    private func loadRecentBuildings() async {
        guard let token = auth.sessionToken else {
            recentState = .notLoggedIn
            return
        }

        recentState = .loading
        do {
            let summaries = try await DiagnosesAPI.list(token: token)
            let recentSummaries = Array(summaries.prefix(5))
            let regionNames = (try? await ReferenceAPI.regions())
                .map { Dictionary(uniqueKeysWithValues: $0.map { ($0.region_id, $0.display_name) }) } ?? [:]

            var buildings: [RecentBuilding] = []
            for summary in recentSummaries {
                let detail = try? await DiagnosesAPI.detail(id: summary.diagnosis_id, token: token)
                let topScenario = detail?.calculation_result.scenarios.min { $0.priority < $1.priority }
                buildings.append(
                    RecentBuilding(
                        id: summary.diagnosis_id,
                        title: "\(BuildingTypeLabel.label(for: summary.building_type_key)) · \(regionNames[summary.region_id] ?? summary.region_id)",
                        dateText: Self.formatDate(summary.created_at),
                        reductionRatePercent: topScenario.map { Int(($0.reduction_rate * 100).rounded()) }
                    )
                )
            }
            recentState = .loaded(buildings)
        } catch {
            recentState = .failed
        }
    }

    private static func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: isoString) ?? {
            isoFormatter.formatOptions = [.withInternetDateTime]
            return isoFormatter.date(from: isoString)
        }()
        guard let date else { return String(isoString.prefix(10)) }

        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "yyyy.MM.dd"
        return outFormatter.string(from: date)
    }

    // 헤더는 sticky(pinned)로 뜨는 순간 리스트 흐름에서 분리되므로, 둥근 위쪽
    // 모서리 + 흰 배경 + 그림자는 부모가 아니라 헤더 자신에게 줘야 한다
    // (안 그러면 고정된 뒤에 모서리가 사라짐 — 웹에서도 같은 이유로 헤더에 직접 줬다).
    private var recentHeader: some View {
        HStack {
            Text("최근 분석한 건물").font(.system(size: 14, weight: .medium)).foregroundStyle(Color(hex: "535353"))
            Spacer()
            HStack(spacing: 2) {
                Text("전체보기")
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color(hex: "176b52"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
    }

    /// + 버튼 — 누르면 서브메뉴 원이 위로 부드럽게 떠오르고, FAB에서 멀어질수록
    /// (위로 갈수록) 색이 옅어진다 (Figma node 28:755).
    private var fab: some View {
        VStack(alignment: .trailing, spacing: 12) {
            ForEach(Array(fabMenuItems.enumerated()), id: \.element.key) { index, item in
                let distanceFromFab = fabMenuItems.count - 1 - index
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { fabOpen = false }
                } label: {
                    Text(item.label)
                        .font(.system(size: 11, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color(hex: "2fcbaa").opacity(0.8)))
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                }
                .opacity(fabOpen ? 1 : 0)
                .scaleEffect(fabOpen ? 1 : 0.75)
                .offset(y: fabOpen ? 0 : 16)
                .allowsHitTesting(fabOpen)
                .animation(.easeOut(duration: 0.3).delay(fabOpen ? Double(distanceFromFab) * 0.06 : 0), value: fabOpen)
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { fabOpen.toggle() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.brand400))
                    .shadow(color: Color.brand400.opacity(0.3), radius: 8, y: 2)
                    .rotationEffect(.degrees(fabOpen ? 45 : 0))
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 70)
        // 메뉴 열렸을 때 바깥(화면 전체)을 탭하면 닫힌다.
        .background(alignment: .topLeading) {
            if fabOpen {
                Color.black.opacity(0.001)
                    .frame(width: 2000, height: 2000)
                    .offset(x: -1900, y: -1900)
                    .onTapGesture { withAnimation { fabOpen = false } }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("어떤 건물을 찾으시나요?")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.brand100, lineWidth: 1))

            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                Image(systemName: "bell")
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                Circle().fill(.red).frame(width: 8, height: 8).offset(x: -4, y: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // 예전엔 VStack + Spacer로 배지를 위에, 타이틀을 아래에 밀어붙이는 방식이었는데,
    // heroHeight가 화면 폭에 따라 달라지다 보니 타이틀 2줄이 히어로 바닥 여백
    // 없이 바로 잘리는 기기가 있었다(PM 리포트, 2026-09-12: "최근 분석한 건물"
    // 섹션을 침범할 정도로 잘림). 웹 원본(HomePage.tsx)도 애초에 Spacer가 아니라
    // 절대좌표(top-[13px]/bottom-[38px])로 고정해뒀던 거라, 그 방식 그대로
    // overlay(alignment:)로 옮겨서 바닥 여백을 항상 38pt로 보장한다.
    // height를 파라미터로 직접 받아 ZStack 자체에 .frame(height:)를 강제한다.
    // 예전엔 외부(NavigationLink 쪽)의 .frame(height:)에만 기대고 heroBanner
    // 내부는 크기를 전혀 지정하지 않았는데, 이 프로젝트가 타겟팅하는 iOS 27
    // 베타에서 resizable Image가 든 ZStack이 그 외부 제약을 무시하고 원본
    // 이미지 크기 기준으로 커져서 검색바까지 침범하는 버그가 있었다
    // (PM 리포트, 2026-09-12 — 실기기에서 직접 재현 확인).
    private func heroBanner(height: CGFloat) -> some View {
        ZStack {
            Image("home-hero-house")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.8)
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .top)
        }
        .frame(height: height)
        .clipped()
        .overlay(alignment: .topLeading) {
            HStack(spacing: 4) {
                Text("AI 진단 시작하기").font(.system(size: 12, weight: .semibold))
                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(.systemBackground))
            .foregroundStyle(.primary)
            .clipShape(Capsule())
            .padding(.leading, 10)
            .padding(.top, 10)
        }
        .overlay(alignment: .bottomLeading) {
            Text("이런 리모델링\n가능하다고?")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, 13)
                .padding(.bottom, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // 시스템 텍스트 크기(설정 > 손쉬운 사용 > 손쉬운 사용 크게 글씨 등)를 키워둔
        // 기기에서는 SwiftUI가 .font(.system(size:))로 지정한 값도 확대해버려서,
        // 38pt 고정 여백 계산이 깨지고 다시 잘려 보인다(PM 리포트, 2026-09-12
        // 재확인 — 시뮬레이터 기본 설정에서는 재현되지 않았다). 이 배너는 Figma
        // 픽셀값을 그대로 맞춘 마케팅성 고정 레이아웃이라 시스템 글씨 크기 설정과
        // 무관하게 항상 같은 크기로 고정한다.
        .dynamicTypeSize(.large)
    }
}

/// GET /api/v1/diagnoses(+상세)로 조립한 실제 진단 이력 1건. 사진은 서버에
/// 원본을 저장하지 않으므로(PRD) 썸네일은 항상 장식용 그라디언트다.
private struct RecentBuilding: Identifiable {
    let id: UUID
    let title: String
    let dateText: String
    /// 상세 조회가 실패했거나 시나리오가 없으면 nil — 이 경우 숫자를 지어내지
    /// 않고 그냥 안 보여준다.
    let reductionRatePercent: Int?
}

private struct RecentBuildingCard: View {
    let building: RecentBuilding

    var body: some View {
        HStack(spacing: 13) {
            // PM 요청(2026-09-12)으로 썸네일 확대: 101x85 -> 118x100.
            LinearGradient(colors: [Color(hex: "e4efe9"), Color(hex: "7fae93")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 118, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text(building.title).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "535353"))

                HStack(spacing: 8) {
                    Text("분석완료")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color(hex: "2fcbaa").opacity(0.8))
                        .clipShape(Capsule())
                    Text(building.dateText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "535353").opacity(0.8))
                }

                // Figma 원본 스펙은 label 5px/배지 7px/날짜 8px이었지만, 실제
                // 기기에서 재보니 너무 작아 읽기 어렵다는 PM 피드백(2026-09-12)에
                // 따라 가독성 기준으로 키웠다 — 위계(값 > 라벨/배지/날짜)는 유지.
                // "예상 비용"은 대응하는 실제 API 필드가 없어(kiwi248,
                // 2026-09-12) 애초에 없다 — reductionRatePercent도 상세 조회가
                // 실패했거나 시나리오가 없으면 지어내지 않고 생략한다.
                if let reductionRatePercent = building.reductionRatePercent {
                    metricBox(label: "에너지 절감률", value: "\(reductionRatePercent)%", valueSize: 19)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 6).padding(.trailing, 16).padding(.vertical, 8)
        .frame(height: 128)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        .overlay(alignment: .trailing) {
            Image("home-chevron")
                .resizable()
                .frame(width: 6, height: 12)
                .padding(.trailing, 14)
        }
        // heroBanner와 같은 이유로 시스템 글씨 크기 설정과 무관하게 고정 —
        // 128pt 고정 카드 높이에 맞춘 픽셀 레이아웃이라 텍스트가 커지면 잘린다.
        .dynamicTypeSize(.large)
    }

    private func metricBox(label: String, value: String, valueSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Color(hex: "535353").opacity(0.8))
            Text(value).font(.system(size: valueSize, weight: .semibold)).foregroundStyle(Color(hex: "176b52"))
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(width: 98, height: 46, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 1)
    }
}

#Preview {
    HomeView().environment(AuthState()).environment(DiagnosisNavigationPath())
}
