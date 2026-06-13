import builder
import gleam/float
import gleam/io
import sara/json

/// 🦑 Performs serialization code generation for your Gleam project.
///
/// The `sara` cli is not configurable by default.
/// With the JSON module of ***Sara*** you can with the help of `//@json_encode()` and `//@json_decode()` generates type-safe JSON encoding and decoding functions for your Gleam custom types at build time.
/// 
/// > ⚠️ The generated JSON code relies on :
/// > - [`json`](https://hexdocs.pm/gleam_json/) package for the json encoder.
/// > - [`stdlib`](https://hexdocs.pm/gleam_stdlib/) package for the json decoder.
/// > So make sure to have them inside your project.
///
pub fn main() -> Nil {
  io.println("🦑 Start Sara")

  let #(_, duration) =
    elapsed(fn() {
      builder.execute_builders([
        json.json_serializable_builder(
          json.Config([
            json.CustomCodec(
              type_name: "Timestamp",
              module_path: "gleam/time/timestamp",
              encode: fn(_, _, variable, _, _) {
                json.GeneratedCode(
                  "json.string(timestamp.to_rfc3339("
                    <> variable
                    <> ", calendar.utc_offset))",
                  ["gleam/time/calendar", "gleam/time/timestamp"],
                  [],
                )
              },
              decode: fn(_, _, _, _) {
                json.GeneratedCode(
                  "{
    use date <- decode.then(decode.string)
    case timestamp.parse_rfc3339(date) {
      Ok(timestamp) -> decode.success(timestamp)
      Error(_) -> decode.failure(timestamp.system_time(), \"Timestamp\")
    }
  }",
                  ["gleam/time/calendar", "gleam/time/timestamp"],
                  [],
                )
              },
              zero: fn(_, _, _, _) {
                Ok(
                  json.GeneratedCode(
                    "timestamp.system_time()",
                    ["gleam/time/timestamp"],
                    [],
                  ),
                )
              },
            ),
            json.CustomCodec(
              type_name: "TimeOfDay",
              module_path: "gleam/time/calendar",
              encode: fn(_, _, variable, _, _) { json.GeneratedCode("{
    let calendar.TimeOfDay(hours:, minutes:, seconds:, nanoseconds:) = " <> variable <> "
    json.object([
      #(\"hours\", json.int(hours)),
      #(\"minutes\", json.int(minutes)),
      #(\"seconds\", json.int(seconds)),
      #(\"nanoseconds\", json.int(nanoseconds)),
    ])
          }", ["gleam/time/calendar"], []) },
              decode: fn(_, _, _, _) {
                json.GeneratedCode(
                  "{
    use hours <- decode.field(\"hours\", decode.int)
    use minutes <- decode.field(\"minutes\", decode.int)
    use seconds <- decode.field(\"seconds\", decode.int)
    use nanoseconds <- decode.field(\"nanoseconds\", decode.int)
    decode.success(calendar.TimeOfDay(hours:, minutes:, seconds:, nanoseconds:))
  }",
                  ["gleam/time/calendar"],
                  [],
                )
              },
              zero: fn(_, _, _, _) {
                Ok(
                  json.GeneratedCode(
                    "calendar.TimeOfDay(hours: 0, minutes: 0, seconds: 0, nanoseconds: 0)",
                    ["gleam/time/calendar"],
                    [],
                  ),
                )
              },
            ),
          ]),
        ),
      ])
    })

  let duration = duration /. 1_000_000_000.0

  io.println(
    "Finished in " <> float.to_precision(duration, 3) |> float.to_string <> "s",
  )

  exit(0)
}

@external(erlang, "sara_ffi", "elapsed")
@external(javascript, "./sara_ffi.mjs", "elapsed")
pub fn elapsed(during fun: fn() -> a) -> #(a, Float)

@external(erlang, "sara_ffi", "exit")
@external(javascript, "./sara_ffi.mjs", "exit")
fn exit(n: Int) -> Nil
