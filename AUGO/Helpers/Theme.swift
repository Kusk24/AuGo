import SwiftUI

struct Theme {
    static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()

        // Title colors
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.Brand.primary)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.Brand.primary)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}
