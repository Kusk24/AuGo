import SwiftUI

struct CreatePostMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresentedFromHome: Bool

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            VStack(spacing: 12) {          // ↓ smaller spacing

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.systemGray6))
                        .overlay(
                            Image("CampusMap")
                                .resizable()
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                        )
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

                    // Marker
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.Brand.coin)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Text("1")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                )
                                .padding(.trailing, 40)
                                .padding(.bottom, 60)
                        }
                    }
                }
                .padding(.horizontal)

                // Button right under the map
                Button {
                    dismiss()
                    isPresentedFromHome = false
                } label: {
                    Text("Confirm post")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.Brand.primary)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Create Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Text("200")
                        .font(.subheadline.bold())

                    ZStack {
                        Circle()
                            .fill(Color.Brand.coin)
                            .frame(width: 22, height: 22)
                        Text("£")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }

                    Image(systemName: "bell.fill")
                        .foregroundColor(Color.Brand.primary)
                }
            }
        }
    }
}
