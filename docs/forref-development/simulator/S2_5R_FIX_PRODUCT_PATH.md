# S2.5R-FIX — discipline and substitution product path

Goal’s product rule now covers Yellow, direct send-off, second-caution send-off, and substitution.

`Record` freezes the command, then, when the scripted outcome is success, completes that same simulated commit in the intent. The label is `SIMULATED SAVED — not production D1`. Match Report is rebuilt from the established row.

Known failure and unknown stay on `Saving — simulated` until an explicit resolve. They do not become success.

A second Yellow still does not create a send-off. Second-caution send-off is a separate Record action and is stored as `SECOND_CAUTION`. Direct send-off stays `DIRECT`.

Mobile Session can open Sending-off and Substitution without the watch shell. Huawei Watch GT 4 “layout not fit” stays deferred.

Continuous live ticking is still a research limitation. Match time is the research elapsed clock, frozen at activation.

## Windows combined retest

```text
cd D:\forref\forref
git switch cursor/forref-simulator-s2-5-product-operations
git pull --ff-only
cd research\hf_prototype
flutter pub get
flutter run -d windows
```

Load `s21MatchReportOps`. Record Away Yellow `#6`, the same Yellow again (no send-off), a separate second-caution send-off, Home direct send-off `#4`, and Home substitution `#9` out / `#17` in. Each success should read `SIMULATED SAVED` and appear once in Match Report. No resolve tap.
