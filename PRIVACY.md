# Privacy

Nuntius reads your chat exports. That is a lot of trust, so here is exactly
what happens to them.

## What leaves your device

Nothing, unless you tap share.

Nuntius has no account system, no server, no cloud sync, no crash reporting and
no analytics SDK. It makes no network requests at all. There is no build flag
or debug mode that changes this — the code contains no networking layer to
enable.

If you tap **Share** on a Wrapped card or a PDF report, that one file is handed
to your operating system's share sheet, and whatever you pick from there
receives it. That is the only path out.

## What is stored, and where

When you import a chat, Nuntius:

1. copies the `.txt` export into the app's **private** storage directory —
   the sandboxed area only this app can read, not your gallery, not shared
   storage, not a cloud folder; and
2. writes a small index entry (title, participant names, message count, date
   range, score) so the chat can be listed and reopened.

Message text is never written anywhere else. Statistics are recomputed from the
stored export each time you open a chat, so there is no second copy of your
conversation sitting in a database.

## What is not collected

No contacts. No phone numbers beyond whatever names appear inside the export
itself. No device identifiers. No usage data. No advertising identifiers.

## Deleting it

**Settings → Delete everything** removes every stored export, every saved
report and every setting. Because nothing was ever sent anywhere, that deletes
all of it — there is no other copy to request.

You can also delete a single chat from the saved-chats list. Either way, your
original export file and the conversation in WhatsApp itself are untouched.

## Permissions

Nuntius asks for file access once, so you can pick the export you want to
import. It does not read files you have not chosen.
