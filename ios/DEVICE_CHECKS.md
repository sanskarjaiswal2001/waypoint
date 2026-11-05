# iPhone checks for the 0.3.0 preview

Record the IPA version/build, source revision, iPhone model, iOS version and installation method. The earlier LiveContainer navigation report covers 0.2.0. Leave each result pending until it has been checked on the new build.

Reported test device: iPhone 18 Pro, iOS 27.0.1, LiveContainer. The host version remains to be recorded. These environment details do not mark any 0.3.0 check as passed.

Keep personal locations and routes private. A short outcome and any non-location error text are enough for the public record.

| Check | Expected result | Result |
| --- | --- | --- |
| Update in the same installation/container | Saved places, selected world and preferences survive. | Pending |
| Save, rename and relaunch | The new name persists; the destination address and location do not change. | Pending |
| Quests | Add/edit a task, link a saved place, complete and Undo. XP reverses with Undo. The task survives relaunch. | Pending |
| Focus | Pause/resume and reopen the app. Expiry asks for confirmation and does not complete the task. Early finish earns no focus bonus. | Pending |
| New worlds | Check the eleven added worlds, their fonts, POIs, player/vehicle markers and Quests entry. | Pending |
| Compact screen, landscape and large text | Long destination content scrolls; Preview route or Start navigation remains reachable. | Pending |
| VoiceOver | World cards announce the world and game name, including the selected state. Primary controls have useful labels. | Pending |
| Bicycle | Preview a cycling route and check its mode, route and ETA. It must not silently use the car profile. | Pending |
| Heading and follow | Stationary GPS course does not override the compass. A navigation gesture pauses following; it resumes after eight seconds or immediately with Locate. | Pending |
| Spoken turns and units | Hear useful directions in both distance preferences, including a change after preview. Extra themed wording stays clear of nearby or urgent turns. | Pending |
| Wrong turn and route failure | Recalculation follows the mode's deviation rules. A failed request retains guidance and reports the failure; a stopped trip cannot be replaced by a later response. | Pending |
| Arrival | Guidance ends at the destination. A linked quest remains incomplete until explicitly completed. | Pending |
| Permission changes | Denial/revocation stops guidance and explains how to restore access. Reduced accuracy is identified; restoring permission reacquires a fresh fix. | Pending |
| Locked/background guidance | With the tested installation's permission, guidance and speech continue as expected. Returning to the app shows current progress. | Pending |
| Shared destinations | Coordinates and supported map links wait for confirmation. Short links resolve after confirmation. Incoming proposals cannot replace active guidance. | Pending |
| Release notes and channels | What's New appears once after an update and can be reopened. Update links and feedback target upstream. | Pending |

For LiveContainer, record the host version/instance as well. A hosted result does not establish SideStore/AltStore behavior, and a direct installation does not establish LiveContainer behavior.
