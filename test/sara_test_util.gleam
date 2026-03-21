import birdie
import booklet
import builder/asset
import builder/simulate
import gleam/list
import gleam/option.{None}
import sara/json

pub fn prepare_basic_json_test(
  config: json.Config,
  files: List(simulate.VirtualFile),
  outputs: List(#(String, String)),
) {
  let #(assert_read, read) = testable_callback2(fn(_, _) { Ok(None) })
  let #(assert_read_bits, read_bits) = testable_callback2(fn(_, _) { Ok(None) })
  let #(assert_write, write) =
    testable_callback3(fn(_, asset: asset.BuildAsset, contents) {
      let output = list.find(outputs, fn(output) { output.0 == asset.path })
      case output {
        Ok(output) -> {
          birdie.snap(contents, title: output.1)
        }
        _ -> {
          panic as { "File " <> asset.path <> " should not be used" }
        }
      }
      Ok(Nil)
    })
  let #(assert_write_bits, write_bits) =
    testable_callback3(fn(_, _, _) { Ok(Nil) })

  simulate.simulate_builder_run(
    builders: [
      json.json_serializable_builder(config),
    ],
    project_files: files,
    read:,
    read_bits:,
    write:,
    write_bits:,
  )

  assert_read(0)
  assert_read_bits(0)
  assert_write(list.length(outputs))
  assert_write_bits(0)
}

fn testable_callback2(execute: fn(a, b) -> x) {
  let call = booklet.new(0)

  #(
    fn(expected) {
      assert booklet.get(call) == expected
    },
    fn(a: a, b: b) -> x {
      booklet.update(call, fn(i) { i + 1 })
      execute(a, b)
    },
  )
}

fn testable_callback3(execute: fn(a, b, c) -> x) {
  let call = booklet.new(0)

  #(
    fn(expected) {
      assert booklet.get(call) == expected
    },
    fn(a: a, b: b, c: c) -> x {
      booklet.update(call, fn(i) { i + 1 })
      execute(a, b, c)
    },
  )
}
