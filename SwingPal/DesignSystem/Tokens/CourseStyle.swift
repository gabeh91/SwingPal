import SwiftUI

/// Semantic surfaces shared by the course, score and equipment compositions.
enum CourseStyle {
    enum Typography {
        static let courseName = Font.system(.largeTitle, weight: .bold).width(.condensed)
        static let title = Font.system(.title, weight: .bold).width(.condensed)
        static let number = Font.system(.title2, weight: .bold).width(.condensed)

    }

    static let ground = Color("CourseGround")
    static let surface = Color("CourseSurface")
    static let ink = Color("CourseInk")
    static let muted = Color("CourseMuted")
    static let action = Color("CourseAction")
    static let onAction = Color("CourseOnAction")
    static let line = Color("CourseLine")
    static let wash = Color("CourseWash")
    static let warning = Color("CourseWarning")
}
