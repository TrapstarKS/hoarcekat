# Bolt's Journal

## 2024-05-22 - [Recursive DescendantAdded Scanning]

Learning:
Using `DescendantAdded` on a Service (like Workspace) fires for *every single descendant* added.
If you also call `instance:GetDescendants()` inside the `DescendantAdded` callback, you create an O(N^2) (or worse) performance complexity.
For example, dragging a model with 1000 parts into Workspace triggers the event 1000 times. If each event scans the subtree (even if empty), it's massive overhead.

Action:
When using `DescendantAdded`, assume you are visiting every node. Do NOT call `GetDescendants()` inside the callback. Instead, just process the `child` passed to the callback.
Also, be careful when "cleaning up" or "watching" instances that are NOT relevant (like non-stories), as connecting listeners to everything in the game causes memory bloat and CPU usage on every property change.

## 2024-05-22 - [Throttled Hot Reloading]

Learning:
Connecting directly to `Script.Changed` (or `Source` property changes) to trigger a hot-reload causes the plugin to recompile and re-run code on every single keystroke.
This creates massive input lag for the user, especially if the story involves heavy setup (instantiating UI, requiring modules).

Action:
Always throttle or debounce hot-reloading logic tied to user input (like script editing). A delay of 0.5s is usually sufficient to wait for the user to pause typing before attempting to reload the environment.
