import SwiftUI

struct ContentView: View {
    @State private var message: String = "Tap the button"

    var body: some View {
        VStack(spacing: 20) {
            Text(message)
                .font(.title)

            Button("Hello World") {
                message = "Hello World"
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

