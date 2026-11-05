import SwiftUI
import WaypointKit

struct QuestsView: View {
    let model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Quest?
    @State private var showCompleted = false
    var body: some View {
        NavigationStack {
            List {
                if let problem = model.quests.problem { Text(problem).foregroundStyle(.secondary) }
                Section {
                    Text("Tasks stay on this device. You decide when each quest is complete. Arrival and focus timers never complete a quest for you.").font(.footnote)
                    Button("Add a quest") { draft = Quest(title: "", place: model.questPlaceDraft) }
                    Toggle("Show completed quests", isOn: $showCompleted)
                }
                if model.quests.book.quests.isEmpty { ContentUnavailableView("Your quests", systemImage: "checklist", description: Text("Add an everyday task, a place to visit or time to focus.")) }
                ForEach(model.quests.book.quests.filter { showCompleted || $0.completedAt == nil }) { quest in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(quest.title).font(.headline)
                            if !quest.notes.isEmpty { Text(quest.notes) }
                            if let place = quest.place {
                                Text(place.name).font(.subheadline)
                                Button("Navigate") { model.select(place); dismiss() }
                            }
                            HStack {
                                Button("Edit") { draft = quest }
                                Spacer()
                                if quest.completedAt == nil { Button("Complete quest") { model.quests.complete(quest.id) }.buttonStyle(.borderedProminent) }
                                else { Button("Reopen quest") { model.quests.undo(quest.id) } }
                            }
                            if quest.completedAt == nil {
                                if model.quests.book.focus?.questID == quest.id, let clock = model.quests.book.focus {
                                    Text("Focus: \(model.quests.focusSeconds / 60):\(String(format: "%02d", model.quests.focusSeconds % 60))").monospacedDigit()
                                    if model.quests.focusSeconds == 0 && clock.status != .finished {
                                        Text("Did you finish your focus time?")
                                        HStack { Button("Yes, finished") { model.quests.finishFocus(true) }; Button("Finish without bonus") { model.quests.finishFocus(false) } }
                                    } else if clock.status == .running {
                                        HStack { Button("Pause") { model.quests.pauseFocus() }; Button("Finish early") { model.quests.finishFocus(false) } }
                                    } else if clock.status == .paused { Button("Resume focus") { model.quests.resumeFocus() } }
                                    else { Text("Focus finished. Complete the quest when you're ready.").font(.footnote) }
                                } else {
                                    Button("Start \(quest.focusMinutes)-minute focus") { model.quests.startFocus(quest.id) }
                                        .disabled(model.quests.book.focus != nil && model.quests.book.focus?.status != .finished)
                                }
                            }
                        }.padding(.vertical, 6)
                    }.swipeActions { Button("Delete", role: .destructive) { model.quests.delete(quest.id) } }
                }
                Section {
                    NavigationLink("Your journey") { QuestProfileView(quests: model.quests) }
                    Text("Focus timers do not send background alerts. Reopen Quests to check the timer.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Quests")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if let id = model.quests.lastCompleted, !model.navigating {
                    HStack { Text(model.quests.book.showProgress ? "Quest completed · \(model.quests.book.rewards.first(where: { $0.questID == id })?.xp ?? 20) XP" : "Quest completed"); Spacer(); Button("Undo") { model.quests.undo(id) } }.padding().background(.regularMaterial)
                }
            }
            .sheet(item: $draft) { quest in QuestEditor(quest: quest, model: model) }
            .disabled(model.navigating)
            .task { while !Task.isCancelled { model.quests.now = Date(); do { try await Task.sleep(for: .seconds(1)) } catch { return } } }
        }
        .onDisappear { model.questPlaceDraft = nil }
    }
}

private struct QuestEditor: View {
    @State var quest: Quest
    let model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                TextField("Quest title", text: $quest.title)
                TextField("Notes (optional)", text: $quest.notes, axis: .vertical).lineLimit(3...8)
                Stepper("Focus: \(quest.focusMinutes) minutes", value: $quest.focusMinutes, in: 1...180)
                    .disabled(model.quests.book.focus?.questID == quest.id)
                Section("Place (optional)") {
                    if let place = quest.place { Text(place.name); Button("Remove place") { quest.place = nil } }
                    if let place = model.destination { Button("Use selected destination") { quest.place = place } }
                    ForEach(model.saved) { place in Button(place.name) { quest.place = place } }
                    Text("Choose a saved place or select a destination on the map first.").font(.footnote)
                }
            }.navigationTitle("Quest details")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save quest") { if !model.navigating && model.quests.save(quest) { dismiss() } }.disabled(QuestBook.title(quest.title) == nil || quest.notes.count > 2000) }
                }
        }
    }
}

private struct QuestProfileView: View {
    let quests: QuestModel
    var body: some View {
        Form {
            Toggle("Show progression", isOn: Binding(get: { quests.book.showProgress }, set: { value in _ = quests.change { $0.showProgress = value } }))
            if quests.book.showProgress {
                LabeledContent("Level", value: "\(quests.book.level)")
                LabeledContent("XP", value: "\(quests.book.xp)")
                LabeledContent("Completed quests", value: "\(quests.book.rewards.count)")
                Section("Achievements") {
                    if quests.book.rewards.count >= 1 { Text("First step") }
                    if quests.book.rewards.count >= 10 { Text("Finding your rhythm") }
                    if quests.book.rewards.count >= 50 { Text("Seasoned adventurer") }
                    if quests.book.focusedCount >= 5 { Text("Time well spent") }
                }
                Text("Each completed quest earns 20 XP. A completed focus session of at least ten minutes adds 10 XP. Every 100 XP adds a level. Undo reverses the reward.").font(.footnote)
            }
        }.navigationTitle("Your journey")
    }
}
