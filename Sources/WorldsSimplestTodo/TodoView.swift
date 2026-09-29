import SwiftUI

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @State private var draft = ""
    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            input

            if store.items.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .frame(minWidth: 440, idealWidth: 520, minHeight: 480, idealHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
            inputIsFocused = true
        }
        .onAppear {
            focusInput()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusTodoInput)) { _ in
            focusInput()
        }
    }

    private var input: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("What needs doing?", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .regular, design: .rounded))
                .focused($inputIsFocused)
                .onSubmit(addTask)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(.background)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()

            Text("Type. Press return. Done.")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text("⌥N brings this window back anytime.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.items) { item in
                    taskRow(item)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func taskRow(_ item: TodoItem) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                store.complete(item)
            }
            focusInput()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.secondary)

                Text(item.title)
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Complete \(item.title)")
    }

    private func addTask() {
        let title = draft
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            draft = ""
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            store.add(title)
        }
        draft = ""
        focusInput()
    }

    private func focusInput() {
        DispatchQueue.main.async {
            inputIsFocused = true
        }
    }
}
