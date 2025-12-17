import SwiftUI

struct PostClusterView: View {
    let cluster: PostCluster
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.Brand.primary)
                    .frame(width: 22, height: 22) // ⬅️ smaller (same scale as post pin)

                Text("\(cluster.count)")
                    .font(.caption2.bold()) // ⬅️ smaller text
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
}
