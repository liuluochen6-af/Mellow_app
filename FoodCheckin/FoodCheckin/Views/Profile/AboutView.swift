import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))

            Text("吃喝玩乐打卡")
                .font(.title2.bold())
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

            Text("v1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("记录你的探店足迹\n点亮你的美食地图")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.98, green: 0.96, blue: 0.93).ignoresSafeArea())
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
