import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.black)

            Text("Mellow")
                .font(.title2.bold())
                .foregroundColor(.primary)

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
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
