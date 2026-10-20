import SwiftUI

// Keep the standard date control within narrow layouts at accessibility sizes;
// its separate label still follows the full user-selected Dynamic Type size.
struct RecordDatePicker: View {
    let title: String
    @Binding var selection: Date
    var components: DatePickerComponents = [.date, .hourAndMinute]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
            DatePicker(title, selection: $selection, displayedComponents: components)
                .labelsHidden().datePickerStyle(.compact)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
    }
}
