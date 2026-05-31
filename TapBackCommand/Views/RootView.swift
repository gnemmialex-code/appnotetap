//
//  RootView.swift
//  TapBack Command
//
//  Hosts the main tab navigation and overlays the floating command panel
//  (driven by `AppRouter`). The floating panel is presented above all tabs
//  with a slide-down + fade transition.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var notesVM: NotesViewModel
    @EnvironmentObject private var todoVM: TodoViewModel
    @EnvironmentObject private var captureVM: CaptureViewModel

    // Sheets opened from the floating panel.
    @State private var activeAction: QuickAction?

    var body: some View {
        ZStack(alignment: .top) {
            Constants.Palette.background.ignoresSafeArea()

            TabView(selection: $router.selectedTab) {
                NotesListView()
                    .tabItem { Label("Notes", systemImage: "mic.fill") }
                    .tag(AppRouter.Tab.notes)

                TodoListView()
                    .tabItem { Label("To-Do", systemImage: "checklist") }
                    .tag(AppRouter.Tab.todos)

                CaptureListView()
                    .tabItem { Label("Captures", systemImage: "sparkles") }
                    .tag(AppRouter.Tab.captures)
            }
            .tint(.white)

            // Floating command overlay.
            if router.showFloatingCommand {
                FloatingCommandView { action in
                    router.dismissFloatingCommand()
                    // Slight delay so the panel finishes dismissing first.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        activeAction = action
                    }
                } onDismiss: {
                    router.dismissFloatingCommand()
                }
                .padding(.horizontal, UIScreen.main.bounds.width * (1 - Constants.Layout.floatingWidthFraction) / 2)
                .padding(.top, Constants.Layout.topInset)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        // Route a pending action from an App Intent (e.g. straight to record).
        .onChange(of: router.pendingAction) { _, action in
            guard let action else { return }
            router.dismissFloatingCommand()
            activeAction = action
            router.pendingAction = nil
        }
        // Present the chosen action as a sheet.
        .sheet(item: $activeAction) { action in
            actionSheet(for: action)
                .presentationDetents(action == .voiceNote ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func actionSheet(for action: QuickAction) -> some View {
        switch action {
        case .voiceNote:
            VoiceRecorderView { note in
                notesVM.add(note)
                router.selectedTab = .notes
            }
        case .todo:
            TodoQuickAddView { text, date in
                todoVM.add(text: text, reminderDate: date)
                router.selectedTab = .todos
            }
        case .capture:
            CaptureView()
                .environmentObject(captureVM)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppRouter.shared)
        .environmentObject(NotesViewModel())
        .environmentObject(TodoViewModel())
        .environmentObject(CaptureViewModel())
        .preferredColorScheme(.dark)
}
