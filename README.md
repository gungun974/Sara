# Sara 🦑

Sara is a **serialization code generator** for Gleam.

With ***Sara***, using `//@json_encode()` and `//@json_decode()`, you can generate type-safe JSON encoding and decoding functions for your Gleam custom types at build time.
No need to keep the decoder and encoder up to date 😉

## Usage

First you'll need to add Sara to your project as a dev dependency:

```sh
gleam add sara --dev
```


Then add `//@json_encode()` and/or `//@json_decode()` attributes to the types you want to serialize:

```gleam
//@json_encode()
//@json_decode()
pub type Comment {
  Comment(id: Int, message: String)
}

//@json_encode()
//@json_decode()
pub type Post {
  PostWithoutComment(
    id: Int,
    title: String,
  )
  PostWithComment(
    id: Int,
    title: String,
    comments: List(Comment),
  )
}
```


Then you can generate the code by running the `sara` module:

```sh
gleam run -m sara
```

And that's it! Each time you execute this command, Sara will look for all `*.gleam` files inside the `src` directory and will generate a new `_json.gleam` module for each type annotated with `//@json_encode()` and `//@json_decode()`.

The only downside is that since Sara will never edit one of your files, your annotated types need to be public and not opaque, otherwise the `_json` module can't access and create them

## Supported types

Sara is capable of understanding all of the default Gleam types and more!

The types that are currently supported are:

| Type | Example | Description |
|------|---------|-------------|
| `Bool` | `Bool` | True / False |
| `Int` | `Int` | Integer numbers |
| `Float` | `Float` | Coerce numbers into floating point numbers |
| `String` | `String` | Text strings |
| `List` | `List(Int)` | Lists of any supported type |
| `Tuple` | `#(Int, Float)` | Tuples of any supported types |
| `Type Aliases` | `type Alias = String` | Type aliases are resolved to their underlying type |
| `Custom Types` | `type Node { Leaf(Int) \| Branch(Node, Node) }` | Custom types with multiple variants |
| `Recursive Types` | `type Node { Node(left: Node, right: Node) \| Leaf(Int) }` | Types that reference themselves |
| `Complex Nested Types` | `List(#(String, #(Bool, Int)))` | Arbitrary nesting of supported types |

### Custom Types Without Annotations

When Sara encounters a custom type that is **not** annotated with `//@json_encode()` or `//@json_decode()`, it doesn't attempt to generate nested encoders/decoders automatically. Instead, it adds function parameters to the generated functions, allowing you to provide custom encoders, decoders, or default values.

For example, if you have:

```gleam
//@json_encode()
//@json_decode()
pub type Post {
  Post(id: Int, metadata: CustomMetadata)
}

pub type CustomMetadata {
  CustomMetadata(data: String)
}
```

Sara will generate functions like:

```gleam
pub fn post_to_json(
  post: Post,
  custom_metadata_to_json: fn(CustomMetadata) -> json.Json
) -> json.Json

pub fn post_json_decoder(
  custom_metadata_json_decoder: fn() -> decode.Decoder(CustomMetadata),
  custom_metadata_zero_value: CustomMetadata
) -> decode.Decoder(Post)
```

This allows you to provide your own serialization logic for types that don't have Sara annotations.

## Credit

This project would not be possible without [squirrel](https://github.com/giacomocavalieri/squirrel) inspiring me to create a code generator.
But also the Gleam LSP code action for giving me the idea
