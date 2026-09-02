# Voxtype Indicator

Voxtype Indicator adds a bar widget that appears while voxtype is recording or
transcribing and is absent the rest of the time. The upstream
`gabedunn/voxtype` widget occupies the bar permanently, showing an idle glyph
between dictations; this one leaves no gap at all when there is nothing to say.

## Plugin

| Field | Value |
| --- | --- |
| ID | `metsker/voxtype` |
| Entries | Service: `watcher` · Bar widget: `indicator` |

## Requirements

`voxtype` on `PATH`, with its daemon running. The service reads
`voxtype status --follow --format json`, which emits one JSON line per state
change and one on connect.

## Usage

Add the `indicator` widget from Noctalia's widget picker. It has no click
actions - it is an indicator, and voxtype's own push-to-talk key starts and
stops the recording.

| State | Widget |
| --- | --- |
| `idle` | Hidden |
| `recording` | Microphone glyph |
| `transcribing` | Spinner glyph |
| `error` | Warning glyph |

Hovering shows the tooltip voxtype writes for the current state, which names
the model and the input device.

## Settings

Each visible state has its own glyph, edited with the bar widget's own settings.
They are widget-level rather than plugin-level, so two placements of the widget
can look different.

| Setting | Default | Effect |
| --- | --- | --- |
| Recording glyph | `microphone` | Shown while the microphone is open |
| Transcribing glyph | `loader-2` | Shown while the model works |
| Error glyph | `alert-triangle` | Shown when the daemon reports a failure |

## Notes

The stream lives in a headless service rather than in the widget, so the number
of bars does not change the number of `voxtype status` processes: one, whether
the widget is placed on one monitor or three. The widgets watch the plugin's
shared state and draw what the service publishes.

`runStream` never restarts a stream that dies, and stopping the voxtype daemon
kills one, so the service runs the follow in a shell loop that restarts it. The
loop's `kill -0 "$PPID"` guard ends it once Noctalia is gone. A 15-second tick
re-reads `voxtype status --format json` on top of that, so a wedged stream still
cannot strand the widget in the recording state.
