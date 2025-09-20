import SwiftUI

final class DevPingVM: ObservableObject {
    @Published var output: String = "—"
    private let provider = ChatGPTProvider()

    @MainActor
    func ping() async {
        do {
            let reply = try await provider.send(messages: [
                .init(role: .system, content: "You are a concise assistant."),
                .init(role: .user, content: "Say 'pong' if you can hear me.")
            ])
            output = reply
        } catch {
            output = "Error: \(error.localizedDescription)"
        }
    }
}

struct DevPingView: View {
    @StateObject private var vm = DevPingVM()

    var body: some View {
        VStack(spacing: 16) {
            Text("OpenAI ping").font(.title3)
            Text(vm.output).font(.body).multilineTextAlignment(.center)
            Button("Ping GPT") {
                Task { await vm.ping() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
