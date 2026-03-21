import SwiftUI

enum LDTypography {
    static func hero() -> Font { .custom("AvenirNext-DemiBold", size: 34, relativeTo: .largeTitle) }
    static func title() -> Font { .custom("AvenirNext-DemiBold", size: 28, relativeTo: .title) }
    static func section() -> Font { .custom("AvenirNext-DemiBold", size: 20, relativeTo: .title3) }
    static func body() -> Font { .custom("AvenirNext-Regular", size: 16, relativeTo: .body) }
    static func bodyBold() -> Font { .custom("AvenirNext-DemiBold", size: 16, relativeTo: .body) }
    static func caption() -> Font { .custom("AvenirNext-Regular", size: 13, relativeTo: .caption) }
    static func overline() -> Font { .custom("AvenirNext-DemiBold", size: 11, relativeTo: .caption2) }
}
