import SwiftUI

struct AppIconView: View {
    let app: Application

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)

            Text(app.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 100)
                .foregroundColor(.white)
        }
        .frame(width: 100, height: 125)
    }
}
