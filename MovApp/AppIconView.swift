import SwiftUI

struct AppIconView: View {
    let app: Application

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)

            Text(app.name)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
                .foregroundColor(.white)
        }
        .frame(width: 80, height: 100)
    }
}
