# Quests on iOS

Open Quests from any world's idle map, then choose Add a quest. A title is enough. Notes, a saved/selected place and a focus duration are optional details. From a destination card, Add a quest here carries that place into the editor.

Choose Complete quest yourself. Undo reverses the completion and its XP. Completed quests offer Reopen quest. Deleting a completed quest removes its title and notes while retaining an anonymous reward record. Opening navigation or arriving at a place never completes a quest.

A completion earns 20 XP. Finishing a focus session of at least ten minutes adds 10 XP when the quest is completed. Every 100 XP adds a level. Your journey shows progress and achievements, with a switch to hide progression. Quests remains usable with progression hidden.

Only one focus session can run or be paused at a time. Choose 1 to 180 minutes, then Start focus, Pause or Resume. The timer uses a [monotonic clock that includes device sleep](https://developer.apple.com/documentation/kernel/1646199-mach_continuous_time) while the phone stays on the same boot session. It restores after reopening; after a reboot, wall time provides a bounded fallback. An expired timer asks whether you finished before granting focus credit. Finish early ends it without a bonus. Task completion remains a separate action.

Quest editing and completion banners are suppressed during navigation. This preview has no quest notifications, so it cannot deliver background quest alerts. It also omits photo/character attachments, avatar frames and story chapters from Android. These scope differences remain open for maintainer review.

Quests, linked places and earned progress stay in private storage on the phone. There is no account, upload or sync service. Keep the same installation/container when updating; uninstalling can remove the data. Physical-device persistence across an installer update remains to be checked.
