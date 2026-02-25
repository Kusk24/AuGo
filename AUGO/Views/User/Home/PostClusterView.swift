import SwiftUI

struct PostClusterView: View {
    let cluster: PostCluster
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.Brand.primary.opacity(0.22))
                    .frame(width: 36, height: 36)

                Circle()
                    .fill(Color.Brand.primary)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2.2)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 2)

                Text("\(cluster.count)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
