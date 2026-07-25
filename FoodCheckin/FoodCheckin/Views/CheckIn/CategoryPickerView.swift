import SwiftUI

struct CategoryPickerView: View {
    @Binding var selected: CheckInCategory

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(CheckInCategory.allCases, id: \.self) { category in
                Button {
                    selected = category
                } label: {
                    Text(category.displayName)
                        .font(.subheadline)
                        .foregroundColor(selected == category ? .white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selected == category
                                ? Color.black
                                : Color(UIColor.systemGray6)
                        )
                        .cornerRadius(8)
                }
            }
        }
    }
}
