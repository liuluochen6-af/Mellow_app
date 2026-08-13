import SwiftUI

@main
struct FoodCheckinApp: App {
    @StateObject private var authService = AuthService()

    init() {
        // Bound image/network caching avoids repeated downloads without allowing
        // decoded image data to grow without limit.
        URLCache.shared = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "MellowNetworkCache"
        )
    }

    var body: some Scene {
        WindowGroup {
            if authService.isLoggedIn {
                ContentView()
                    .environmentObject(authService)
                    .tint(.black)
            } else {
                LoginView()
                    .environmentObject(authService)
                    .tint(.black)
            }
        }
    }
}
