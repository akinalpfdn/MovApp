import SwiftUI

struct GridSizeData: Equatable {
    let rows: Int
    let columns: Int
}

struct GridSizeKey: PreferenceKey {
    static var defaultValue: GridSizeData = GridSizeData(rows: 4, columns: 4)
    static func reduce(value: inout GridSizeData, nextValue: () -> GridSizeData) {
        value = nextValue()
    }
}
