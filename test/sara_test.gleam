import builder/simulate.{VirtualFile}
import gleeunit
import sara/json
import sara_test_util

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn empty_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(path: "/entity.gleam", contents: ""),
    ],
    [],
  )
}

pub fn ignore_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
pub type Post {
  Post(id: Int)
}",
      ),
    ],
    [],
  )
}

pub fn basic_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Post {
  Post
}",
      ),
    ],
    [#("/entity_json.gleam", "Basic JSON encode & decode")],
  )
}

pub fn basic_decode_only_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_decode()
pub type Post {
  Post()
}",
      ),
    ],
    [#("/entity_json.gleam", "Basic JSON decode only")],
  )
}

pub fn basic_encode_only_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
pub type Post {
  Post()
}",
      ),
    ],
    [#("/entity_json.gleam", "Basic JSON encode only")],
  )
}

pub fn bool_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Value {
  Value(value: Bool)
}",
      ),
    ],
    [#("/entity_json.gleam", "Bool JSON encode & decode")],
  )
}

pub fn int_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Value {
  Value(value: Int)
}",
      ),
    ],
    [#("/entity_json.gleam", "Int JSON encode & decode")],
  )
}

pub fn float_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Value {
  Value(value: Float)
}",
      ),
    ],
    [#("/entity_json.gleam", "Float JSON encode & decode")],
  )
}

pub fn string_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Value {
  Value(value: String)
}",
      ),
    ],
    [#("/entity_json.gleam", "String JSON encode & decode")],
  )
}

pub fn list_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Value {
  Value(value: List(Int))
}",
      ),
    ],
    [#("/entity_json.gleam", "List JSON encode & decode")],
  )
}

pub fn tuple_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Value {
  Value(value: #(Int, Float))
}",
      ),
    ],
    [#("/entity_json.gleam", "Tuple JSON encode & decode")],
  )
}

pub fn complex_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Value {
  Value(
    bool: Bool,
    int: Int,
    float: Float,
    string: String,
    list: List(Int),
    tuple: #(Int, Float),
    complex: List(#(String, #(Bool, Int))),
  )
}",
      ),
    ],
    [#("/entity_json.gleam", "Complex JSON encode & decode")],
  )
}

pub fn basic_variant_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Password {
  Secure
  Unsecure
}",
      ),
    ],
    [#("/entity_json.gleam", "Basic Variant JSON encode & decode")],
  )
}

pub fn nested_variant_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Node {
  Node(left: Node, right: Node)
  Leaf(value: Int)
}",
      ),
    ],
    [#("/entity_json.gleam", "Nested Variant JSON encode & decode")],
  )
}

pub fn complex_variant_codec_test() {
  sara_test_util.prepare_basic_json_test(
    json.Config([]),
    [
      VirtualFile(
        path: "/entity.gleam",
        contents: "
//@json_encode()
//@json_decode()
pub type Simple {
  Simple(
    simple: String,
  )
}

pub type Alias = String

//@json_encode()
//@json_decode()
pub type Node {
  Node(
    title: String,
    nodes: List(Node),
    bool: Bool,
    int: Int,
    float: Float,
    string: String,
    list: List(Int),
    tuple: #(Int, Float),
    complex: List(#(String, #(Bool, Int))),
    simple: Simple,
    alias: Alias,
  )
  Leaf(
    title: String,
    alias: Alias,
  )
}",
      ),
    ],
    [#("/entity_json.gleam", "Complex Variant JSON encode & decode")],
  )
}
// pub fn multiple_records_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// //@json_encode()
// //@json_decode()
// pub type Comment {
//   Comment(
//     id: Int,
//     message: String,
//   )
// }
//
// //@json_encode()
// //@json_decode()
// pub type Post {
//   Post(
//     id: Int,
//     title: String,
//     messages: List(Comment),
//   )
// }",
//       ),
//     ],
//     [#("/entity_json.gleam", "Multiple Records JSON encode & decode")],
//   )
// }
//
// pub fn multiple_files_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/main.gleam",
//         contents: "
// pub fn main() {
// }",
//       ),
//       VirtualFile(
//         path: "/comment.gleam",
//         contents: "
// //@json_encode()
// //@json_decode()
// pub type Comment {
//   Comment(
//     id: Int,
//     message: String,
//   )
// }",
//       ),
//       VirtualFile(
//         path: "/post.gleam",
//         contents: "
// import comment.{type Comment}
//
// //@json_encode()
// //@json_decode()
// pub type Post {
//   Post(
//     id: Int,
//     title: String,
//     messages: List(Comment),
//   )
// }",
//       ),
//     ],
//     [
//       #(
//         "/comment_json.gleam",
//         "Multiple Records across files (comment) JSON encode & decode",
//       ),
//       #(
//         "/post_json.gleam",
//         "Multiple Records across files (post) JSON encode & decode",
//       ),
//     ],
//   )
// }
//
// pub fn alias_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// pub type Id = Int
//
// //@json_encode()
// //@json_decode()
// pub type Post {
//   Post(
//     id: Id,
//     title: String,
//     content: String,
//   )
// }",
//       ),
//     ],
//     [#("/entity_json.gleam", "Alias JSON encode & decode")],
//   )
// }
//
// pub fn prelude_shadow_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// pub type Int = Float
//
// //@json_encode()
// //@json_decode()
// pub type String {
//   String(
//     value: Bool,
//   )
// }
//
// //@json_encode()
// //@json_decode()
// pub type Post {
//   Post(
//     id: Int,
//     title: String,
//     content: String,
//   )
// }",
//       ),
//     ],
//     [#("/entity_json.gleam", "Prelude shadow JSON encode & decode")],
//   )
// }
//
// pub fn unknow_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/gleam/time/timestamp.gleam",
//         contents: "
// pub opaque type Timestamp {
//   Timestamp(seconds: Int, nanoseconds: Int)
// }
// ",
//       ),
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// import gleam/time/timestamp
//
// pub type Comment {
//   Comment(
//     id: Int,
//     message: String,
//   )
// }
//
// //@json_encode()
// //@json_decode()
// pub type Post {
//   Post(
//     id: Int,
//     title: String,
//     messages: List(Comment),
//     date: timestamp.Timestamp
//   )
//   Error(
//     date: timestamp.Timestamp
//   )
// }",
//       ),
//     ],
//     [#("/entity_json.gleam", "Unknow JSON encode & decode")],
//   )
// }
//
// pub fn nested_unknow_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/gleam/time/timestamp.gleam",
//         contents: "
// pub opaque type Timestamp {
//   Timestamp(seconds: Int, nanoseconds: Int)
// }
// ",
//       ),
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// import gleam/time/timestamp
//
// pub type Comment {
//   Comment(
//     id: Int,
//     message: String,
//   )
// }
//
// //@json_encode()
// //@json_decode()
// pub type Post {
//   Post(
//     id: Int,
//     title: String,
//     messages: List(Comment),
//     date: timestamp.Timestamp
//   )
//   Error(
//     date: timestamp.Timestamp
//   )
// }
//
// //@json_encode()
// //@json_decode()
// pub type Container {
//   Container(
//     posts: List(Post),
//   )
// }
// ",
//       ),
//     ],
//     [#("/entity_json.gleam", "Nested Unknow JSON encode & decode")],
//   )
// }
//
// pub fn recursive_nested_unknow_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/gleam/time/timestamp.gleam",
//         contents: "
// pub opaque type Timestamp {
//   Timestamp(seconds: Int, nanoseconds: Int)
// }
// ",
//       ),
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// import gleam/time/timestamp
//
// pub type Comment {
//   Comment(
//     id: Int,
//     message: String,
//   )
// }
//
// //@json_encode()
// //@json_decode()
// pub type Post {
//   Post(
//     id: Int,
//     title: String,
//     messages: List(Comment),
//     date: timestamp.Timestamp
//   )
//   Error(
//     date: timestamp.Timestamp
//   )
// }
//
// //@json_encode()
// //@json_decode()
// pub type Container {
//   Container(
//     posts: List(Post),
//   )
//   Recursive(Container)
// }
// ",
//       ),
//     ],
//     [#("/entity_json.gleam", "Recursive Nested Unknow JSON encode & decode")],
//   )
// }
//
// pub fn custom_type_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([
//       json.CustomCodec(
//         type_name: "Timestamp",
//         module_path: "gleam/time/timestamp",
//         encode: fn(_, _, variable, _, _) {
//           json.GeneratedCode(
//             "json.string(timestamp.to_rfc3339("
//               <> variable
//               <> ", calendar.utc_offset))",
//             ["gleam/time/calendar", "gleam/time/timestamp"],
//             [],
//           )
//         },
//         decode: fn(_, _, _, _) {
//           json.GeneratedCode(
//             "{
//   use date <- decode.then(decode.string)
//   case timestamp.parse_rfc3339(date) {
//     Ok(timestamp) -> decode.success(timestamp)
//     Error(_) -> decode.failure(timestamp.system_time(), \"Timestamp\")
//   }
// }",
//             ["gleam/time/calendar", "gleam/time/timestamp"],
//             [],
//           )
//         },
//         zero: fn(_, _, _, _) {
//           Ok(
//             json.GeneratedCode(
//               "timestamp.system_time()",
//               ["gleam/time/timestamp"],
//               [],
//             ),
//           )
//         },
//       ),
//     ]),
//     [
//       VirtualFile(
//         path: "/gleam/time/timestamp.gleam",
//         contents: "
// pub opaque type Timestamp {
//   Timestamp(seconds: Int, nanoseconds: Int)
// }",
//       ),
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// import gleam/time/timestamp
//
// pub opaque type Zero {
//   Zero
// }
//
// //@json_encode()
// //@json_decode()
// pub type Container {
//   Container(
//     date: timestamp.Timestamp,
//   )
//   Opaqued(Zero)
// }
// ",
//       ),
//     ],
//     [#("/entity_json.gleam", "Custom type JSON encode & decode")],
//   )
// }
//
// pub fn option_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/gleam/option.gleam",
//         contents: "
// pub type Option(a) {
//   Some(a)
//   None
// }",
//       ),
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// import gleam/option
//
// pub opaque type Zero {
//   Zero
// }
//
// //@json_encode()
// //@json_decode()
// pub type Container {
//   Container(
//     date: option.Option(Int),
//   )
//   Opaqued(Zero)
// }
// ",
//       ),
//     ],
//     [#("/entity_json.gleam", "Option JSON encode & decode")],
//   )
// }
//
// pub fn basic_parameters_polymorphism_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// pub type Either(a, b) {
//   Left(a)
//   Right(b)
// }
//
// //@json_encode()
// //@json_decode()
// pub type Container {
//   Container(
//     res1: Result(Bool, Nil),
//     res2: Result(Int, Nil),
//     either1: Either(Bool, Nil),
//     either2: Either(Int, Nil),
//   )
// }
// ",
//       ),
//     ],
//     [
//       #(
//         "/entity_json.gleam",
//         "Basic Parametric Polymorphism JSON encode & decode",
//       ),
//     ],
//   )
// }
//
// pub fn cant_deep_parameters_polymorphism_codec_test() {
//   sara_test_util.prepare_basic_json_test(
//     json.Config([]),
//     [
//       VirtualFile(
//         path: "/entity.gleam",
//         contents: "
// //@json_encode()
// //@json_decode()
// pub type Either(a, b) {
//   Left(a)
//   Right(b)
// }
//
// //@json_encode()
// //@json_decode()
// pub type Container {
//   Container(
//     either1: Either(Bool, Nil),
//     either2: Either(Int, Nil),
//   )
// }
// ",
//       ),
//     ],
//     [
//       #(
//         "/entity_json.gleam",
//         "Cant Deep Parametric Polymorphism JSON encode & decode",
//       ),
//     ],
//   )
// }
