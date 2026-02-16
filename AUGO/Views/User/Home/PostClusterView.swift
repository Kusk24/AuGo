import SwiftUI

struct PostClusterView: View {
    let cluster: PostCluster
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.Brand.primary)
                    .frame(width: 30, height: 30)

                Text("\(cluster.count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
}
