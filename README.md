# VASample: Virgin Active iOS take-home

A small SwiftUI client for the Virgin Active mock API. You can sign in, see a home screen the server builds for you, book a class (or join the waitlist), set a reminder, and browse the week's timetable.

I focused on the integration: tokens, retries, defensive parsing, and keeping the server as the source of truth. The UI is deliberately simple.

---

## Running it

**Requirements:** Xcode 27 and an iOS 27 simulator. The app's deployment target is iOS 18.

1. Start the mock server (`start.command` / `start.bat` / `start.sh`) and wait for `Responding at http://0.0.0.0:8080`.
2. The app points at `http://localhost:8080` (`VASample/Networking/APIEnvironment.swift`), which works as-is in the simulator. If the server is on another port or machine, or you're running on a real device, change `baseURL` there. I developed against the server running on a Windows machine on my network.
3. Open `VASample.xcodeproj`, pick the `VASample` scheme and an iOS 27 simulator, and run.
4. Sign in with either test user:
   - `avid.runner@virginactive.mock` / `password123`
   - `competitive.swimmer@virginactive.mock` / `password123`

The server speaks plain HTTP. `VASample-Info.plist` allows local networking (`NSAllowsLocalNetworking`) and includes the local network usage description for real devices. Nothing else is relaxed.

**Tests:** run `⌘U` in Xcode, or:
```sh
xcodebuild test -project VASample.xcodeproj -scheme VASample \
  -destination 'platform=iOS Simulator,name=<your iOS 27 simulator>' \
  -only-testing:VASampleTests
```
The tests don't need the server running. Networking is tested through a stubbed `URLProtocol`, and everything above it uses fakes.

---

## How it's put together

```
Views (SwiftUI)  ->  ViewModels (protocol + live + mock)
                          |
          +---------------+---------------+
          |                               |
   TimetableStore (actor)          ReminderScheduler
   cache + booking rules           local notifications
          |
   ClassesAPI / HomeAPI / ProfileAPI / AuthAPI
          |
   APIClient  <->  TokenStore (actor)
   retries, refresh,     tokens, refresh coalescing,
   error decoding        session expiry
```

- **Modules** (`Modules/Auth`, `Home`, `Classes`, `Classes Details`, `Tab Bar`): one folder per feature, with views and view models side by side.
- **View models:** each screen's view model sits behind a protocol, with a live implementation and a mock. Views are generic over the protocol, so every preview runs on mock data and never touches the network.
- **Dependencies:** all dependencies come in through `init` as protocols (`AuthAPIProtocol`, `TimetableStoreProtocol`, `ReminderSchedulerProtocol`…). That's also what makes the view models easy to test.
- **Navigation:** `AppRouter` owns the top-level route (sign-in or tabs) and the selected tab. Each tab has its own `NavigationStack`.
- **Errors:** everything the user sees goes through `UIError` and a single `.errorAlert($error)` modifier. Retry is only offered when it's safe (see below).

---

## Things worth pointing out

### Tokens
- **Access token:** short-lived (`expiresIn: 300`). On a 401, `APIClient` refreshes once and replays the request with the new token.
- **Refresh tokens rotate**, so two requests refreshing at the same time would lock each other out. `TokenStore` is an actor that coalesces refreshes: concurrent 401s share one refresh call. If another request already rotated the token, the store returns the new one without refreshing again.
- **No logout on a chaos 500.** The server throws `ChaosFailure` 500s at random, refresh included. I only sign the user out when the server actually rejects the refresh token. A 500 on refresh is retried and, if it keeps failing, shown as a normal error, with the user still signed in.
- **Session expiry:** when the session really is gone, `TokenStore` emits on `sessionExpirations`. The app clears the cached timetable and goes back to sign-in with a "Session expired" message.
- **Staying signed in:** tokens are saved to the Keychain as a JSON string (`KeychainTokenStorage`, available after first unlock and on this device only). `TokenStore` loads them when it's created. On launch the app shows a spinner, and if there are saved tokens it refreshes straight away, because a 300-second access token is almost certainly expired by then. If the refresh works you land on Home; if it doesn't, you get the sign-in screen. If the server rejected the saved refresh token, you also get a "Session expired" message. Logging out wipes the Keychain entry.

### Retries, and why booking is different
- **GETs** (`/me`, manifest, timetable) are retried in `APIClient` on 5xx and 429: up to 2 retries with exponential backoff.
- **POST and DELETE are never retried blindly.** If a booking request 500s, I can't tell whether it landed.
- **Booking retries live in `TimetableStore`,** which understands the domain. It retries transient failures, and on a retry it treats `409 AlreadyBooked`/`AlreadyWaitlisted` as "the first attempt worked". Cancel does the same with `404 BookingNotFound`.
- The view model never gets a blind "Retry" button for booking, because the store has already done the safe version.

### Server-driven home
- **Block types:** `HomeBlockType` is the discriminator. `HomeBlock` is an enum with a typed model per block.
- **Defensive parsing:** the spec only lists block type names, so I built the models from real responses for both users and made fields optional where they differ (the swimmer's goal has only `id` and `title`).
- **Unknown and broken blocks** are skipped individually instead of failing the whole manifest, as the spec asks. Unknown carousel actions decode to `.unsupported` instead of throwing.
- **`experimental`** isn't part of `HomeBlockType`, so it's skipped like any unknown block. There's nothing to render yet, so I didn't model it.
- **Rendering:** the home screen draws whatever comes back, in the server's order. Badges ("Booked", "Waitlisted") come from the server too. After a booking I reload the manifest instead of writing badge text myself.

### Data: one store for the week
- **The endpoint:** the timetable endpoint returns the whole week whatever `date` you pass (it only changes `selectedDate`). So one fetch covers every class in the home carousel.
- **`TimetableStore`** is an actor that caches the week per club and shares in-flight requests. Booking and cancelling write the server's answer back into it, so Home and Classes stay consistent.
- **Freshness:** there's no TTL. Opening the Classes tab force-refreshes the store, Home uses what's cached, and the booking POST is the final check. If a class filled up in the meantime, the server answers with a waitlist place and the screen updates from that response. Logout clears the store, because `userBookingStatus` is per user.
- **Carousel items:** they only carry a summary (no availability, status or end time). Tapping one resolves the full class from the store, so the confirmation screen has real data and the details view model only ever takes a `ClassInstance`. The Classes tab already has the instance, so it doesn't pay for a second lookup.

### Venue time
The API says to show times as returned, for the venue, not converted to the device's time zone. `Date` drops the offset, so I decode into `VenueDate`, which keeps the instant and the offset parsed from the string. All formatting goes through `VenueDate+Formatting`. A Sea Point class shows Johannesburg time even on a phone set to London.

### Timetable
- **The week:** the Classes tab shows the whole week, grouped by day (days with no classes are hidden), with times in venue time.
- **Statuses:** each class has a chip showing its current status: cancelled, booked, waitlisted, finished, in progress, full (join the waitlist), or how many spots are left.
- **Past classes are greyed out.** Classes that have already started or finished, and cancelled ones, are dimmed. You can still open them to see the details, but the Book and Cancel buttons don't appear, since the server rejects bookings for classes that have started (`422 ClassInPast`).

### Booking flow
- **How I read "confirmation screen":** I read it as the screen you confirm on before anything is sent.
- **The flow:** tap a class (from Home or the timetable) → details screen → **Book** / **Join Waitlist** → confirm alert → POST. The same screen then switches to its confirmed state, with the booking ID or your waitlist position, the reminder, and cancel.
- **Cancelling** asks for confirmation too. If the class starts within 12 hours, the confirmation includes the forfeit warning, and the screen shows it as a banner.
- **Reminders** are local notifications 30 minutes before the class. I only ask for notification permission when you tap Set Reminder. Cancelling the booking removes the reminder.
- **Add to calendar** opens the system event editor (`EKEventEditViewController`), pre-filled with the class, the venue's time zone, the club's name and address as the location, the club's phone number in the notes, and a 30-minute alert. On iOS 17+ that editor runs without calendar permission, so the app never asks for it and has no calendar keys in the Info.plist.
- **The club comes from the home manifest.** The class model only has a club ID, but the `myClub` block has the name, address and phone number. Home saves it into a session-wide `VenueStore` when the manifest loads, and both Home and Classes pass it to the details screen. It's cleared on logout and session expiry, because each user has a different home club.
- **No local "added to calendar" state.** Nothing from the server covers it, and without permission the app can't see whether the event is still there, so a stored flag could be wrong. The button stays the same, and you can add the class again if you want.

---

## Stubbed or unfinished, and how I'd finish it

- **Images:** the brief says to map `imageRef` to assets in the package's `images/` folder, but my package didn't include an `images/` folder, so every image shows the placeholder. `ImageResolver` already maps `imageRef` to an asset name and falls back to the placeholder when an asset is missing, so once I have the images it's just a matter of adding them to the asset catalogue.
- **Base URL:** it's a constant. I'd move it to an `.xcconfig` per environment and read it from Info.plist.
- **Token refresh timing:** I only refresh on a 401, or once at launch. With more time I'd store when the token was issued and refresh shortly before `expiresIn` runs out, which saves a failed round trip.
- **Empty states:** the home carousel can legitimately be empty late on a Sunday. Right now that just renders nothing.
- **UI tests:** there aren't any yet; `VASampleUITests` is still the Xcode template. With more time I'd add a few XCUITests for the main flows (sign in, open a class from Home, book or join the waitlist, cancel inside 12 hours) running against a stubbed API, so they don't depend on the chaos server.
- **Smaller items:**
  - No notification delegate, so a reminder doesn't show while the app is in the foreground.
  - The Classes list flashes its loading overlay when you come back from details.
  - The mocks are compiled into the app target; they should live in Preview Content or behind `#if DEBUG`.

---

## What I noticed about the API

- **Random failures:** about 1 in 6 requests fails with `500 ChaosFailure` (5 out of 30 manifest calls when I measured), and latency ranged from almost nothing to about 4.6s.
- **Gaps in the spec:**
  - Block schemas aren't defined; only the type names are listed.
  - `TimetableDay.classes` points at `kotlin.collections.ArrayList`.
  - `servers` says `localhost:8080`.
- **The timetable `date` parameter doesn't filter.** You always get the full week; it only moves `selectedDate`.
- **Authorization gap:** any signed-in user can read any club's timetable. The swimmer can fetch Sea Point's. That's worth raising.
- **Old access tokens stay valid** after a refresh until they expire. Refresh-token rotation is enforced, though: reusing an old refresh token gets `401 InvalidRefreshToken`.
- **Error codes:** errors share one shape (`error`, `message`, `code`, `requestId`), and `error` is the useful machine-readable field (`AlreadyBooked`, `ClassInPast`, `BookingNotFound`…). Login validation errors are the only ones I saw with `code: "VALIDATION"`.
- **No user waitlist position on classes:** classes only expose `waitlistCount`, not your own position. I can only show your position right after joining, from the booking response.

---

## Tests

137 test cases (Swift Testing), focused on what I'd least want to break:

- **`APIClient`:** bearer header, no network call without a token, GET retries on chaos 500s, POST never retried, refresh-and-replay on 401, a rejected refresh expiring the session, a refresh surviving a 500, error body and decoding failures.
- **`TokenStore` and Keychain:** concurrent refreshes share one call, an already-rotated token is reused, a 500 keeps the session, a 401 ends it. Tokens are loaded on creation and saved on sign-in, rotation and sign-out, and the Keychain round trip is tested. Restoring a saved session at launch is covered for a successful refresh, a rejected one, and nothing saved.
- **`TimetableStore`:** caching, shared fetches, lookups served from the week, bookings applied to the cache, 500 → retry, 409/404 on a retry treated as success, a 409 on the first attempt treated as a real error, giving up after max retries, the local fallback when the refetch after a cancel fails.
- **Decoding:** unknown, malformed and experimental blocks skipped, optional fields, unsupported actions, `VenueDate` keeping the offset and rendering venue time.
- **View models:** sign-in validation (password rules are left to the server) and error messages, home loading/retry/class lookup/double-tap guard/logout, the timetable keeping your selected day, and the booking rules on details (can book/cancel, 12-hour window, waitlist, recovered bookings, reminders 30 minutes before, permission denied, calendar pre-fill).

---

## AI usage

- **Where I used it:** I used Claude Code throughout. It scaffolded the network layer from the swagger spec, probed the live API to find where it differs from the docs, reviewed my code against this brief, and helped with `TimetableStore`, the test suite and a first draft of this README.
- **What I accepted vs rejected:**
  - I designed my own view model pattern (protocol + `ObservableObject` + mocks) for SignInView and query the LLM to create view models for my other views.
  - I turned down a 60-second cache TTL in favour of refreshing when the Classes tab opens, and then removed the cache clearing it added when Home opens. The server is the source of truth, and the booking POST is the real check.
  - I made the details view model take a full `ClassInstance` rather the suggested than IDs, so the timetable doesn't refetch a class it already has (reducing API calls).
  - I kept it from adding comments everywhere.
- **With more time:** I'd settle routing and the data layer earlier, write tests alongside features instead of at the end, and finish the image work above.
