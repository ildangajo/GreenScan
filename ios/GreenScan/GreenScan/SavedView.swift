import SwiftUI

/// frontend/src/features/saved/SavedPage.tsx 포팅. 하트는 nav-saved와 같은
/// 아이콘(웹에서도 같은 SVG path 재사용)이라 그대로 가져다 tint만 바꿔 쓴다.
struct SavedView: View {
    @State private var items = SavedBuilding.samples

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 21) {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                Text("저장").font(.system(size: 18)).foregroundStyle(Color(hex: "535353"))
                Spacer()
            }
            .padding(.horizontal, 21)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if items.isEmpty {
                Spacer()
                Text("저장한 건물이 아직 없어요.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach($items) { $item in
                            SavedCard(item: $item)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

private struct SavedBuilding: Identifiable {
    let id = UUID()
    let title: String
    let reductionRate: Int
    var saved = true

    static let samples = [
        SavedBuilding(title: "서울시 강남구 OO빌딩", reductionRate: 52),
        SavedBuilding(title: "서울시 강북구 OO카페", reductionRate: 24),
        SavedBuilding(title: "서울시 강서구 OO빌라", reductionRate: 21),
        SavedBuilding(title: "서울시 송파구 OO빌딩", reductionRate: 60),
    ]
}

private struct SavedCard: View {
    @Binding var item: SavedBuilding

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [Color(hex: "e4efe9"), Color(hex: "7fae93")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                Text("에너지 절감률").font(.system(size: 11)).foregroundStyle(Color(hex: "535353").opacity(0.7))
                Text("\(item.reductionRate)%").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color(hex: "176b52"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Spacer(minLength: 0)

            Button {
                item.saved.toggle()
            } label: {
                Image("nav-saved")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(item.saved ? Color(hex: "2fcbaa") : Color(hex: "B0B0B0"))
            }
            .padding(.trailing, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}

#Preview {
    SavedView()
}
