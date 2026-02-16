import SwiftUI

struct PostClusterView: View {
    let cluster: PostCluster
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.Brand.primary)
                    .frame(width: 24, height: 24)

                Text("\(cluster.count)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
}
