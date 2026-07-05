import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {

            Text("Climate Engine")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Version 0.1.0-alpha")
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 250)

            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

        }
        .frame(minWidth: 450,
               minHeight: 300)
        .padding()
    }
}

#Preview {
    ContentView()
}
