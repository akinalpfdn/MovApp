import SwiftUI

struct AppIconView: View {
    let app: Application

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)

            Text(app.name)
                .font(.system(size: 13))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)
                .foregroundColor(.white)
        }
        .frame(width: 120, height: 150)
    }
}
