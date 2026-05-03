import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: AIChatViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            history
            Divider()
            composer
        }
        .frame(minWidth: 320, minHeight: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                chatGlyph

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.status.mode.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(statusDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Picker("", selection: Binding(
                    get: { viewModel.selectedMode },
                    set: { viewModel.selectMode($0) }
                )) {
                    ForEach(AIChatProviderMode.userSelectable, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 156)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help("Close chat")
            }

            if viewModel.selectedMode == .openRouterKey {
                settingsRow
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.tertiary)
                            Text("Ask Habibi something")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 190)
                    }

                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if viewModel.isSending {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Bubbly is typing")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 14)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let last = viewModel.messages.last else {
                    return
                }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.18))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(red: 1.0, green: 0.93, blue: 0.93))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                TextField("Message", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await viewModel.send() }
                    }

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                .help("Send")

                Button {
                    viewModel.clearHistory()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.messages.isEmpty)
                .help("Clear history")
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var settingsRow: some View {
        switch viewModel.selectedMode {
        case .sponsored:
            EmptyView()
        case .openRouterKey:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    SecureField(viewModel.hasOpenRouterKey ? "Saved key" : "OpenRouter key", text: $viewModel.keyDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Key") {
                        viewModel.saveOpenRouterKey()
                    }
                    Button {
                        viewModel.removeOpenRouterKey()
                    } label: {
                        Image(systemName: "key.slash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.hasOpenRouterKey)
                    .help("Remove OpenRouter key")
                }

                HStack(spacing: 8) {
                    TextField("Model", text: $viewModel.modelDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            viewModel.saveOpenRouterModel()
                        }
                    Button("Save Model") {
                        viewModel.saveOpenRouterModel()
                    }
                }
            }
        case .offline:
            EmptyView()
        }
    }

    private var statusDetail: String {
        if let remaining = viewModel.remainingToday {
            return "\(viewModel.status.detail), \(remaining) left"
        }
        if let model = viewModel.modelDetail {
            return model
        }
        return viewModel.status.detail
    }

    private var chatGlyph: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.96, green: 0.99, blue: 1.0),
                            Color(red: 0.50, green: 0.82, blue: 0.96),
                            Color(red: 0.35, green: 0.59, blue: 0.88)
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 30
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.56), lineWidth: 2)
                )

            Circle()
                .fill(Color.white.opacity(0.42))
                .frame(width: 15, height: 10)
                .offset(x: -9, y: -10)

            HStack(spacing: 7) {
                Circle()
                    .fill(Color(red: 0.06, green: 0.13, blue: 0.22))
                    .frame(width: 5, height: 7)
                Circle()
                    .fill(Color(red: 0.06, green: 0.13, blue: 0.22))
                    .frame(width: 5, height: 7)
            }
            .offset(y: -2)

            HStack(spacing: 16) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.44, blue: 0.64).opacity(0.28))
                    .frame(width: 7, height: 5)
                Circle()
                    .fill(Color(red: 1.0, green: 0.44, blue: 0.64).opacity(0.28))
                    .frame(width: 7, height: 5)
            }
            .offset(y: 8)

            ChatSmile()
                .stroke(
                    Color(red: 0.06, green: 0.13, blue: 0.22),
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                )
                .frame(width: 13, height: 8)
                .offset(y: 6)
        }
        .frame(width: 34, height: 34)
    }

    private func messageBubble(_ message: AIChatMessage) -> some View {
        let isUser = message.role == .user

        return HStack {
            if isUser {
                Spacer(minLength: 36)
            }

            Text(message.content)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .foregroundStyle(isUser ? Color.white : Color(red: 0.09, green: 0.20, blue: 0.31))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isUser ? Color.accentColor : Color(red: 0.90, green: 0.96, blue: 1.0))
                )

            if !isUser {
                Spacer(minLength: 36)
            }
        }
        .padding(.horizontal, 14)
    }
}

private struct ChatSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}
