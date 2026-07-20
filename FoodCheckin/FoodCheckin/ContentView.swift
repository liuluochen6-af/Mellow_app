import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var checkInService = CheckInService()
    @State private var selectedTab = 0
    @State private var showNewCheckIn = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                CalendarView()
                    .tag(0)
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("日历")
                    }

                MapView()
                    .tag(1)
                    .tabItem {
                        Image(systemName: "map")
                        Text("地图")
                    }

                Color.clear
                    .tag(2)
                    .tabItem {
                        Text(" ")
                    }

                StatsView()
                    .tag(3)
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("统计")
                    }

                ProfileMainView()
                    .tag(4)
                    .tabItem {
                        Image(systemName: "person")
                        Text("我的")
                    }
            }
            .tint(Color(red: 0.76, green: 0.6, blue: 0.42))

            Button {
                showNewCheckIn = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(red: 0.76, green: 0.6, blue: 0.42))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            .offset(y: -20)
        }
        .fullScreenCover(isPresented: $showNewCheckIn) {
            NewCheckInView()
                .environmentObject(checkInService)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                selectedTab = 0
                showNewCheckIn = true
            }
        }
    }
}