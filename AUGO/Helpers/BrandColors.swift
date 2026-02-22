import SwiftUI

extension Color {
    enum Brand {
        static let primary        = Color("BrandPrimary")
        static let coin           = Color("BrandCoin")
        static let appBackground  = Color(
            uiColor: UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1)
                }
                return UIColor(red: 0.96, green: 0.95, blue: 0.98, alpha: 1)
            }
        )
        static let surface = Color(
            uiColor: UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.17, green: 0.18, blue: 0.22, alpha: 1)
                }
                return .white
            }
        )
        static let surfaceMuted = Color(
            uiColor: UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.21, green: 0.22, blue: 0.27, alpha: 1)
                }
                return UIColor.systemGray6
            }
        )
    }
}
