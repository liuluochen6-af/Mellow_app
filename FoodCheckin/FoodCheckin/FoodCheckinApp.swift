import SwiftUI
import SwiftData

@main
struct FoodCheckinApp: App {
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            if authService.isLoggedIn {
                ContentView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .modelContainer(for: [CachedCheckIn.self])
    }
}
