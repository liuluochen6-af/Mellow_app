import SwiftUI

struct CategoryPickerView: View {
    @Binding var selected: CheckInCategory

    private let columns = Array(repeating: GridItem(.flexible()), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(CheckInCategory.allCases, id: \.self) { category in
                Button {
                    selected = category
                } label: {
                    VStack(spacing: 6) {
                        Text(category.icon)
                            .font(.title)
                        Text(category.displayName)
                            .font(.caption)
                            .foregroundColor(selected == category ? .white : Color(red: 0.35, green: 0.25, blue: 0.15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selected == category
                            ? Color(red: 0.76, green: 0.6, blue: 0.42)
                            : Color(.systemGray6)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
}
