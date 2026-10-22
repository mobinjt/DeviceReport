# DeviceReport

Tells the owner's apps' backends which devices they run on: the model, the system and app
versions, the app's language and whether notifications are on, so the people running an app can
help a user and see which versions are in use. Nothing that identifies the device. A report is
sent only when something changed since the last one.

- **DeviceReport:** `DeviceReporter` and `ClientDevice.current(notifications:)`, for the app. How
  to send a report is passed in, so any backend works.
- **DeviceReportCore:** `ClientDevice` alone, Foundation only, so a server or an admin tool on
  Linux or the Mac shares the same model.

## Adding it to an app

1. Add the package by its URL (Xcode > Add Package Dependencies) and the **DeviceReport** product
   to the app target.
2. Make the reporter once, with how to send a report to your backend:

   ```swift
   import DeviceReport

   let reporter = DeviceReporter { device in
       var request = URLRequest(url: server.appending(path: "me/device"))
       request.httpMethod = "PUT"
       request.httpBody = try JSONEncoder().encode(device)
       _ = try await URLSession.shared.data(for: request)
   }
   ```

   Throw when the backend didn't take the report; the next report tries again.

3. Report when the app opens and comes to the foreground, once the user has an account:

   ```swift
   let settings = await UNUserNotificationCenter.current().notificationSettings()
   await reporter.report(notifications: .init(authorization: settings.authorizationStatus,
                                              isEnabledInApp: notificationsSwitch))
   ```

   The reporter sends nothing when the device is the same as last time in this launch.

## The backend's side

Take one `ClientDevice` as JSON and keep it with the user's session (each installed app is one
device):

```json
{ "system": "ios", "model": "iPhone17,1", "systemVersion": "26.0.1", "appVersion": "1.0",
  "appBuild": "42", "appLanguage": "fa", "notifications": "quiet" }
```

`system` is `ios`, `ipados`, `macos`, `visionos` or `android`; `notifications` is `off`, `quiet`
(provisional) or `on`. Keep `sanitized` values: printable ASCII, at most 40 characters each.

## How it's built

- iOS 18 and macOS 15, Swift 6; `DeviceReportCore` also builds on Linux. No dependencies.
- The model comes from `utsname` (the simulated device's in the simulator, `hw.model` on the Mac),
  the system version from `ProcessInfo`, the app's version, build and language from its bundle.
- Its log messages use the app's bundle ID as the subsystem, category `device`.

`swift test` covers sanitizing, the JSON names, the current device, notification states, sending
only changes and trying a failed report again.

## License

MIT. See [LICENSE](LICENSE).
