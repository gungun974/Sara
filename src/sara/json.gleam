//// JSON Serialization Code Generator
////
//// This module provides a builder that automatically generates JSON encoding
//// and decoding functions for Gleam custom types annotated with `//@json_encode`
//// and/or `//@json_decode`.
////
//// ## Basic Usage
////
//// Annotate your types:
////
//// ```gleam
//// //@json_encode
//// //@json_decode
//// pub type User {
////   User(name: String, age: Int)
//// }
//// ```
////
//// This generates a companion `*_json.gleam` file containing:
//// - `pub fn user_to_json(user: User) -> json.Json`
//// - `pub fn user_json_decoder() -> decode.Decoder(User)`
////
//// ## Custom Codecs
////
//// For types requiring special serialization logic, provide a `CustomCodec`:
////
//// ```gleam
//// json.json_serializable_builder(
////   json.Config([
////     json.CustomCodec(
////       type_name: "Timestamp",
////       module_path: "gleam/time/timestamp",
////       encode: fn(_, _, variable, _, _) {
////         json.GeneratedCode(
////           "json.string(timestamp.to_rfc3339(" <> variable <> ", calendar.utc_offset))",
////           ["gleam/time/calendar", "gleam/time/timestamp"],
////           [],
////         )
////       },
////       decode: fn(_, _, _, _) {
////         json.GeneratedCode(
////           "{
////   use date <- decode.then(decode.string)
////   case timestamp.parse_rfc3339(date) {
////     Ok(timestamp) -> decode.success(timestamp)
////     Error(_) -> decode.failure(timestamp.system_time(), \"Timestamp\")
////   }
//// }",
////           ["gleam/time/calendar", "gleam/time/timestamp"],
////           [],
////         )
////       },
////       zero: fn(_, _, _, _) {
////         Ok(json.GeneratedCode("timestamp.system_time()", ["gleam/time/timestamp"], []))
////       },
////     ),
////   ]),
//// )
//// ```
////
//// ## Codec Resolution Order
////
//// 1. **Built-in types**: `Int`, `Float`, `Bool`, `String`, `List`, tuples
//// 2. **Custom codecs**: Types registered via `CustomCodec` in config
//// 3. **Annotated types**: Types with `//@json_encode` or `//@json_decode`
//// 4. **Fallback**: Unresolved types become function parameters
////

import builder
import builder/asset
import builder/context.{type BuildContext}
import builder/format
import builder/inspect
import builder/module.{type Module}
import glance.{type CustomType}
import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/set.{type Set}
import gleam/string
import justin

/// Represents generated code with its dependencies and required arguments
///
/// Used internally to track code generation, required imports, and custom
/// function parameters needed for encoding/decoding operations.
pub type GeneratedCode {
  GeneratedCode(
    code: String,
    imports: List(String),
    arguments: List(#(String, String)),
  )
}

type CustomEncoder {
  CustomEncoder(
    type_name: String,
    module_path: String,
    encode: fn(BuildContext, glance.Type, String, Module, Module) ->
      GeneratedCode,
  )
}

type CustomDecoder {
  CustomDecoder(
    type_name: String,
    module_path: String,
    decode: fn(BuildContext, glance.Type, Module, Module) -> GeneratedCode,
  )
}

type CustomZeroValue {
  CustomZeroValue(
    type_name: String,
    module_path: String,
    zero: fn(BuildContext, glance.Type, Module, Module) ->
      Result(GeneratedCode, Nil),
  )
}

/// Allows you to define how a specific type should be serialized to JSON,
/// deserialized from JSON, and what its zero/default value should be.
/// *Note: the zero value is only use for decode failure of variants type*
pub type CustomCodec {
  CustomCodec(
    type_name: String,
    module_path: String,
    encode: fn(BuildContext, glance.Type, String, Module, Module) ->
      GeneratedCode,
    decode: fn(BuildContext, glance.Type, Module, Module) -> GeneratedCode,
    zero: fn(BuildContext, glance.Type, Module, Module) ->
      Result(GeneratedCode, Nil),
  )
}

/// Configuration for the JSON serialization builder
pub type Config {
  Config(custom_codecs: List(CustomCodec))
}

/// Creates a builder that generates JSON encoding and decoding functions.
pub fn json_serializable_builder(config: Config) {
  builder.new_gleam_builder(fn(ctx, input) {
    let encoders = {
      let json_encodes =
        input.module.custom_types |> inspect.filter_attributes("json_encode")

      use <- bool.guard(list.is_empty(json_encodes), [])

      [
        GeneratedCode(code: "", imports: ["gleam/json"], arguments: []),
        ..list.map(json_encodes, fn(entry) {
          json_create_custom_type_encode_function(
            config,
            ctx,
            entry.1,
            input.module,
          )
        })
        |> list.reverse()
      ]
    }

    let decoders = {
      let json_decodes =
        input.module.custom_types |> inspect.filter_attributes("json_decode")

      use <- bool.guard(list.is_empty(json_decodes), [])

      [
        GeneratedCode(
          code: "",
          imports: ["gleam/dynamic/decode"],
          arguments: [],
        ),
        ..list.map(json_decodes, fn(entry) {
          json_create_custom_type_decode_function(
            config,
            ctx,
            entry.1,
            input.module,
          )
        })
        |> list.reverse()
      ]
    }

    let codecs = list.append(encoders, decoders)

    use <- bool.guard(list.is_empty(codecs), Nil)

    let imports =
      [input.module.path]
      |> list.append(
        list.map(codecs, fn(codec) { codec.imports })
        |> list.fold([], fn(acc, imports) { list.append(acc, imports) }),
      )

    let output =
      "import " <> imports |> list.unique() |> string.join("\nimport ") <> "\n"

    let output =
      output
      <> codecs
      |> list.map(fn(codec) { codec.code })
      |> string.join("\n")

    let assert Ok(code) = format.format_gleam_code(output)

    let _ =
      context.write(
        ctx,
        input.file |> asset.change_extension("_json.gleam"),
        code,
      )

    Nil
  })
}

fn get_generated_module_name(path: String) -> String {
  path <> "_json"
}

//! Encode

fn json_create_custom_type_encode_function(
  config: Config,
  ctx: BuildContext,
  custom_type: CustomType,
  module: Module,
) {
  let x = justin.snake_case(custom_type.name)

  let GeneratedCode(code, imports, arguments) =
    json_encode_custom_type(config, ctx, custom_type, x, module, set.new())

  let output =
    "pub fn "
    <> x
    <> "_to_json("
    <> [
      x <> ": " <> module_name_for_path(module.name) <> custom_type.name,
      ..list.map(arguments, fn(argument) {
        case argument.1 {
          "" -> argument.0
          _ -> argument.0 <> ":" <> argument.1
        }
      })
    ]
    |> list.unique
    |> string.join(",")
    <> ") -> json.Json {\n"

  let output = output <> code
  let output = output <> "}"

  GeneratedCode(output, imports, arguments)
}

fn json_encode_custom_type(
  config: Config,
  ctx: BuildContext,
  custom_type: CustomType,
  variable: String,
  module: Module,
  custom_type_path: Set(glance.CustomType),
) -> GeneratedCode {
  let output = "case " <> variable <> "{\n"

  let variants =
    list.map(custom_type.variants, fn(variant) {
      json_encode_variant(
        config,
        ctx,
        variant,
        case custom_type.variants {
          [_] -> False
          _ -> True
        },
        module,
        custom_type_path,
      )
    })

  let output =
    output
    <> variants
    |> list.map(fn(variant) { variant.code })
    |> string.join("\n")
  let output = output <> "}\n"

  GeneratedCode(
    output,
    list.map(variants, fn(variant) { variant.imports })
      |> list.fold([], fn(acc, imports) { list.append(acc, imports) }),
    list.map(variants, fn(variant) { variant.arguments })
      |> list.fold([], fn(acc, arguments) { list.append(acc, arguments) }),
  )
}

fn json_encode_variant(
  config: Config,
  ctx: BuildContext,
  variant: glance.Variant,
  has_variant_type: Bool,
  module: Module,
  custom_type_path: Set(glance.CustomType),
) -> GeneratedCode {
  let output = ""

  let output =
    output
    <> module_name_for_path(module.name)
    <> variant.name
    <> case list.is_empty(variant.fields) {
      False -> {
        let parameters =
          list.index_map(variant.fields, fn(field, i) {
            case field {
              glance.LabelledVariantField(label:, ..) -> label <> ":"
              glance.UnlabelledVariantField(..) -> "field" <> int.to_string(i)
            }
          })
          |> string.join(",")

        "(" <> parameters <> ")"
      }
      _ -> ""
    }
    <> "->\n"
  let output = output <> "json.object([\n"

  let output =
    output
    <> case has_variant_type {
      True -> {
        "#(\""
        <> "type"
        <> "\","
        <> "json.string(\""
        <> justin.snake_case(variant.name)
        <> "\")"
        <> "),\n"
      }
      _ -> ""
    }

  let fields =
    list.index_map(variant.fields, fn(field, i) {
      let variable = case field {
        glance.LabelledVariantField(label:, ..) -> label
        glance.UnlabelledVariantField(..) -> "field" <> int.to_string(i)
      }

      case field.item {
        glance.VariableType(..) ->
          GeneratedCode("todo as \"cant handle generic\"", [], [])
        _ -> {
          let GeneratedCode(code, imports, arguments) =
            json_encode_type(
              config,
              ctx,
              field.item,
              variable,
              module,
              module,
              custom_type_path,
            )
          GeneratedCode(
            "#(\"" <> variable <> "\"," <> code <> "),\n",
            imports,
            arguments,
          )
        }
      }
    })

  let output =
    output
    <> {
      fields
      |> list.map(fn(field) { field.code })
      |> string.join("")
    }

  let output = output <> "])\n"

  GeneratedCode(
    output,
    list.map(fields, fn(field) { field.imports })
      |> list.fold([], fn(acc, imports) { list.append(acc, imports) }),
    list.map(fields, fn(field) { field.arguments })
      |> list.fold([], fn(acc, arguments) { list.append(acc, arguments) }),
  )
}

fn json_encode_type(
  config: Config,
  ctx: BuildContext,
  type_: glance.Type,
  variable: String,
  current_module: Module,
  original_module: Module,
  custom_type_path: Set(glance.CustomType),
) -> GeneratedCode {
  let is_prelude = inspect.is_prelude_type(ctx, type_, current_module)

  case type_ {
    glance.NamedType(name:, parameters:, ..) -> {
      case name, is_prelude {
        "Int", True -> GeneratedCode("json.int(" <> variable <> ")", [], [])
        "Float", True -> GeneratedCode("json.float(" <> variable <> ")", [], [])
        "Bool", True -> GeneratedCode("json.bool(" <> variable <> ")", [], [])
        "String", True ->
          GeneratedCode("json.string(" <> variable <> ")", [], [])
        "List", True -> {
          let assert [type_, ..] = parameters
          let list_encoder =
            json_encode_type(
              config,
              ctx,
              type_,
              "x",
              current_module,
              original_module,
              custom_type_path,
            )
          GeneratedCode(
            "json.array("
              <> variable
              <> ", fn (x) {"
              <> { list_encoder.code }
              <> "})",
            list_encoder.imports,
            list_encoder.arguments,
          )
        }
        _, _ ->
          json_encode_type_generic(
            config,
            ctx,
            type_,
            variable,
            current_module,
            original_module,
            custom_type_path,
          )
      }
    }
    glance.TupleType(elements:, ..) -> {
      let codes =
        list.index_map(elements, fn(element, i) {
          json_encode_type(
            config,
            ctx,
            element,
            variable <> "." <> int.to_string(i),
            current_module,
            original_module,
            custom_type_path,
          )
        })

      GeneratedCode(
        "json.preprocessed_array([\n"
          <> codes |> list.map(fn(code) { code.code }) |> string.join(",\n")
          <> "])",
        list.map(codes, fn(code) { code.imports })
          |> list.fold([], fn(acc, imports) { list.append(acc, imports) }),
        list.map(codes, fn(code) { code.arguments })
          |> list.fold([], fn(acc, arguments) { list.append(acc, arguments) }),
      )
    }
    glance.FunctionType(..) ->
      json_encode_type_generic(
        config,
        ctx,
        type_,
        variable,
        current_module,
        original_module,
        custom_type_path,
      )
    _ -> GeneratedCode("todo", [], [])
  }
}

fn json_encode_type_generic(
  config: Config,
  ctx: BuildContext,
  type_: glance.Type,
  variable: String,
  current_module: Module,
  original_module: Module,
  custom_type_path: Set(glance.CustomType),
) -> GeneratedCode {
  case
    virtual_type_definition(
      inspect.find_type_definition(ctx, type_, current_module),
      ctx,
      type_,
      current_module,
    )
  {
    Ok(type_defintion) ->
      case type_defintion {
        inspect.TypeAlias(source:, module:) ->
          json_encode_type(
            config,
            ctx,
            source.definition.aliased,
            variable,
            module,
            original_module,
            custom_type_path,
          )
        inspect.CustomType(source:, module:) -> {
          let custom_encoders = [
            CustomEncoder(
              type_name: "Option",
              module_path: "gleam/option",
              encode: fn(_, _, variable, _, _) {
                let assert glance.NamedType(parameters:, ..) = type_
                let assert [type_, ..] = parameters
                let code =
                  json_encode_type(
                    config,
                    ctx,
                    type_,
                    "x",
                    current_module,
                    original_module,
                    custom_type_path,
                  )

                GeneratedCode(
                  "case "
                    <> variable
                    <> "{option.None->json.null()"
                    <> "option.Some(x)->"
                    <> code.code
                    <> "}",
                  list.append(["gleam/option"], code.imports),
                  code.arguments,
                )
              },
            ),
          ]

          let encoder =
            list.find_map(
              list.append(
                custom_encoders,
                list.map(config.custom_codecs, fn(codec) {
                  CustomEncoder(
                    type_name: codec.type_name,
                    module_path: codec.module_path,
                    encode: codec.encode,
                  )
                }),
              ),
              fn(custom_encoder) {
                case
                  source.definition.name == custom_encoder.type_name
                  && module.path == custom_encoder.module_path
                {
                  True -> Ok(custom_encoder.encode)
                  _ -> Error(Nil)
                }
              },
            )

          case encoder {
            Ok(encode) ->
              encode(ctx, type_, variable, current_module, original_module)
            _ ->
              case inspect.find_attribute(source, "json_encode") {
                Ok(_) -> {
                  let other_arguments = case
                    set.contains(custom_type_path, source.definition)
                  {
                    False -> {
                      let custom_type_path =
                        set.insert(custom_type_path, source.definition)
                      json_encode_custom_type(
                        config,
                        ctx,
                        source.definition,
                        "",
                        module,
                        custom_type_path,
                      ).arguments
                    }
                    _ -> []
                  }

                  case module.path == original_module.path {
                    True ->
                      GeneratedCode(
                        justin.snake_case(source.definition.name)
                          <> "_to_json("
                          <> [
                          variable,
                          ..list.map(other_arguments, fn(argument) {
                            argument.0
                          })
                        ]
                        |> list.unique
                        |> string.join(",")
                          <> ")",
                        [],
                        other_arguments,
                      )
                    False ->
                      GeneratedCode(
                        get_generated_module_name(module.name)
                          <> "."
                          <> justin.snake_case(source.definition.name)
                          <> "_to_json("
                          <> [
                          variable,
                          ..list.map(other_arguments, fn(argument) {
                            argument.0
                          })
                        ]
                        |> list.unique
                        |> string.join(",")
                          <> ")",
                        [get_generated_module_name(module.path)],
                        other_arguments,
                      )
                  }
                }
                Error(_) -> {
                  let parameters = case type_ {
                    glance.NamedType(parameters:, ..) -> parameters
                    _ -> []
                  }
                  let function =
                    justin.snake_case(source.definition.name)
                    <> case parameters {
                      [] -> ""
                      _ ->
                        "_"
                        <> list.map(parameters, fn(parameter) {
                          case parameter {
                            glance.NamedType(name:, ..) ->
                              justin.snake_case(name)
                            _ -> ""
                          }
                        })
                        |> string.join("_")
                    }
                    <> "_to_json"

                  GeneratedCode(
                    function <> "(" <> variable <> ")",
                    [module.path],
                    [
                      #(
                        function,
                        "fn("
                          <> module_name_for_path(module.name)
                          <> source.definition.name
                          <> case parameters {
                          [] -> ""
                          _ ->
                            "("
                            <> list.map(parameters, fn(parameter) {
                              case parameter {
                                glance.NamedType(name:, ..) -> name
                                _ -> ""
                              }
                            })
                            |> string.join(",")
                            <> ")"
                        }
                          <> ") -> json.Json",
                      ),
                    ],
                  )
                }
              }
          }
        }
      }
    Error(_) -> {
      let parameters = case type_ {
        glance.NamedType(parameters:, ..) -> parameters
        _ -> []
      }
      let function =
        justin.snake_case(case type_ {
          glance.NamedType(name:, ..) -> name
          _ -> ""
        })
        <> case parameters {
          [] -> variable
          _ ->
            "_"
            <> list.map(parameters, fn(parameter) {
              case parameter {
                glance.NamedType(name:, ..) -> justin.snake_case(name)
                _ -> ""
              }
            })
            |> string.join("_")
        }
        <> "_to_json"

      GeneratedCode(function <> "(" <> variable <> ")", [], [
        #(function, ""),
      ])
    }
  }
}

//! Decode

fn json_create_custom_type_decode_function(
  config: Config,
  ctx: BuildContext,
  custom_type: CustomType,
  module: Module,
) {
  let x = justin.snake_case(custom_type.name)

  let GeneratedCode(code, imports, arguments) =
    json_decode_custom_type(config, ctx, custom_type, module, set.new())

  let output =
    "pub fn "
    <> x
    <> "_json_decoder("
    <> list.map(arguments, fn(argument) {
      case argument.1 {
        "" -> argument.0
        _ -> argument.0 <> ":" <> argument.1
      }
    })
    |> list.unique
    |> string.join(",")
    <> ") -> decode.Decoder("
    <> module_name_for_path(module.name)
    <> custom_type.name
    <> ") {\n"
  let output = output <> code
  let output = output <> "}"

  GeneratedCode(output, imports, arguments)
}

fn json_decode_custom_type(
  config: Config,
  ctx: BuildContext,
  custom_type: CustomType,
  module: Module,
  custom_type_path: Set(glance.CustomType),
) -> GeneratedCode {
  let has_variant_type = case custom_type.variants {
    [_] -> False
    _ -> True
  }

  let variants =
    list.map(custom_type.variants, fn(variant) {
      json_decode_variant(
        config,
        ctx,
        variant,
        has_variant_type,
        module,
        custom_type_path,
      )
    })

  let output = case has_variant_type {
    True -> {
      let output = "use variant <- decode.field(\"type\", decode.string)\n"

      let output = output <> "case variant {\n"

      let output =
        output
        <> variants
        |> list.map(fn(variant) { variant.code })
        |> string.join("\n")

      let zero_value =
        list.find_map(custom_type.variants, fn(variant) {
          get_variant_zero_value(config, ctx, variant, module, set.new())
        })

      let output =
        output
        <> "_ -> decode.failure("
        <> case zero_value {
          Ok(zero_value) -> zero_value.code
          _ -> justin.snake_case(custom_type.name) <> "_zero_value"
        }
        <> ", \""
        <> custom_type.name
        <> "\" )\n"
      let output = output <> "}\n"

      GeneratedCode(output, [], case zero_value {
        Ok(_) -> []
        _ -> [
          #(
            justin.snake_case(custom_type.name) <> "_zero_value",
            module_name_for_path(module.name) <> custom_type.name,
          ),
        ]
      })
    }
    False -> {
      GeneratedCode(
        variants
          |> list.map(fn(variant) { variant.code })
          |> string.join("\n"),
        [],
        [],
      )
    }
  }

  GeneratedCode(
    output.code,
    list.map(variants, fn(variant) { variant.imports })
      |> list.fold([], fn(acc, imports) { list.append(acc, imports) })
      |> list.append(output.imports),
    list.map(variants, fn(variant) { variant.arguments })
      |> list.fold([], fn(acc, arguments) { list.append(acc, arguments) })
      |> list.append(output.arguments),
  )
}

fn json_decode_variant(
  config: Config,
  ctx: BuildContext,
  variant: glance.Variant,
  has_variant_type: Bool,
  module: Module,
  custom_type_path: Set(glance.CustomType),
) -> GeneratedCode {
  let output = ""

  let fields =
    list.index_map(variant.fields, fn(field, i) {
      let variable = case field {
        glance.LabelledVariantField(label:, ..) -> label
        glance.UnlabelledVariantField(..) -> "field" <> int.to_string(i)
      }

      case field.item {
        glance.VariableType(..) ->
          GeneratedCode("todo as \"cant handle generic\"", [], [])
        _ -> {
          let GeneratedCode(code, imports, arguments) =
            json_decode_type(
              config,
              ctx,
              field.item,
              variable,
              module,
              module,
              custom_type_path,
            )
          GeneratedCode(
            "use "
              <> variable
              <> "<- decode.field(\""
              <> variable
              <> "\","
              <> code
              <> ")\n",
            imports,
            arguments,
          )
        }
      }
    })

  let output =
    output
    <> {
      fields
      |> list.map(fn(field) { field.code })
      |> string.join("")
    }

  let output =
    output
    <> "decode.success("
    <> module_name_for_path(module.name)
    <> variant.name
    <> case list.is_empty(variant.fields) {
      False -> {
        let parameters =
          list.index_map(variant.fields, fn(field, i) {
            case field {
              glance.LabelledVariantField(label:, ..) -> label <> ":"
              glance.UnlabelledVariantField(..) -> "field" <> int.to_string(i)
            }
          })
          |> string.join(",")

        "(" <> parameters <> ")"
      }
      _ -> ""
    }
    <> ")"

  GeneratedCode(
    case has_variant_type {
      True ->
        "\"" <> justin.snake_case(variant.name) <> "\"-> {" <> output <> "}"
      False -> output
    },
    list.map(fields, fn(field) { field.imports })
      |> list.fold([], fn(acc, imports) { list.append(acc, imports) }),
    list.map(fields, fn(field) { field.arguments })
      |> list.fold([], fn(acc, arguments) { list.append(acc, arguments) }),
  )
}

fn json_decode_type(
  config: Config,
  ctx: BuildContext,
  type_: glance.Type,
  variable: String,
  current_module: Module,
  original_module: Module,
  custom_type_path: Set(glance.CustomType),
) -> GeneratedCode {
  let is_prelude = inspect.is_prelude_type(ctx, type_, current_module)

  case type_ {
    glance.NamedType(name:, parameters:, ..) -> {
      case name, is_prelude {
        "Int", True -> GeneratedCode("decode.int", [], [])
        "Float", True ->
          GeneratedCode(
            "decode.one_of(decode.float, [decode.map(decode.int, int.to_float)])",
            ["gleam/int"],
            [],
          )
        "Bool", True -> GeneratedCode("decode.bool", [], [])
        "String", True -> GeneratedCode("decode.string", [], [])
        "List", True -> {
          let assert [type_, ..] = parameters
          let list_decoder =
            json_decode_type(
              config,
              ctx,
              type_,
              variable,
              current_module,
              original_module,
              custom_type_path,
            )
          GeneratedCode(
            "decode.list(" <> { list_decoder.code } <> ")",
            list_decoder.imports,
            list_decoder.arguments,
          )
        }
        _, _ ->
          json_decode_type_generic(
            config,
            ctx,
            type_,
            variable,
            current_module,
            original_module,
            custom_type_path,
          )
      }
    }
    glance.TupleType(elements:, ..) -> {
      let codes =
        list.map(elements, fn(element) {
          json_decode_type(
            config,
            ctx,
            element,
            variable,
            current_module,
            original_module,
            custom_type_path,
          )
        })

      GeneratedCode(
        "{"
          <> codes
        |> list.index_map(fn(code, i) {
          "use "
          <> { "field" <> int.to_string(i) }
          <> " <- decode.field("
          <> int.to_string(i)
          <> ","
          <> code.code
          <> ")"
        })
        |> string.join("\n")
          <> "decode.success(#("
          <> codes
        |> list.index_map(fn(_, i) { "field" <> int.to_string(i) })
        |> string.join(",")
          <> "))"
          <> "}",
        list.map(codes, fn(code) { code.imports })
          |> list.fold([], fn(acc, imports) { list.append(acc, imports) }),
        list.map(codes, fn(code) { code.arguments })
          |> list.fold([], fn(acc, arguments) { list.append(acc, arguments) }),
      )
    }
    glance.FunctionType(..) ->
      json_decode_type_generic(
        config,
        ctx,
        type_,
        variable,
        current_module,
        original_module,
        custom_type_path,
      )
    _ -> GeneratedCode("todo", [], [])
  }
}

fn json_decode_type_generic(
  config: Config,
  ctx: BuildContext,
  type_: glance.Type,
  variable: String,
  current_module: Module,
  original_module: Module,
  custom_type_path: Set(glance.CustomType),
) -> GeneratedCode {
  case
    virtual_type_definition(
      inspect.find_type_definition(ctx, type_, current_module),
      ctx,
      type_,
      current_module,
    )
  {
    Ok(type_defintion) ->
      case type_defintion {
        inspect.TypeAlias(source:, module:) ->
          json_decode_type(
            config,
            ctx,
            source.definition.aliased,
            variable,
            module,
            original_module,
            custom_type_path,
          )
        inspect.CustomType(source:, module:) -> {
          let custom_decoders = [
            CustomDecoder(
              type_name: "Option",
              module_path: "gleam/option",
              decode: fn(_, _, _, _) {
                let assert glance.NamedType(parameters:, ..) = type_
                let assert [type_, ..] = parameters
                let code =
                  json_decode_type(
                    config,
                    ctx,
                    type_,
                    variable,
                    current_module,
                    original_module,
                    custom_type_path,
                  )

                GeneratedCode(
                  "decode.optional(" <> code.code <> ")",
                  code.imports,
                  code.arguments,
                )
              },
            ),
          ]

          let decoder =
            list.find_map(
              list.append(
                custom_decoders,
                list.map(config.custom_codecs, fn(codec) {
                  CustomDecoder(
                    type_name: codec.type_name,
                    module_path: codec.module_path,
                    decode: codec.decode,
                  )
                }),
              ),
              fn(custom_decoder) {
                case
                  source.definition.name == custom_decoder.type_name
                  && module.path == custom_decoder.module_path
                {
                  True -> Ok(custom_decoder.decode)
                  _ -> Error(Nil)
                }
              },
            )

          case decoder {
            Ok(decode) -> decode(ctx, type_, current_module, original_module)
            _ ->
              case inspect.find_attribute(source, "json_decode") {
                Ok(_) -> {
                  let other_arguments = case
                    set.contains(custom_type_path, source.definition)
                  {
                    False -> {
                      let custom_type_path =
                        set.insert(custom_type_path, source.definition)
                      json_decode_custom_type(
                        config,
                        ctx,
                        source.definition,
                        module,
                        custom_type_path,
                      ).arguments
                    }
                    _ -> []
                  }

                  case module.path == original_module.path {
                    True ->
                      GeneratedCode(
                        justin.snake_case(source.definition.name)
                          <> "_json_decoder("
                          <> list.map(other_arguments, fn(argument) {
                          argument.0
                        })
                        |> list.unique
                        |> string.join(",")
                          <> ")",
                        [],
                        other_arguments,
                      )
                    False ->
                      GeneratedCode(
                        get_generated_module_name(module.name)
                          <> "."
                          <> justin.snake_case(source.definition.name)
                          <> "_json_decoder("
                          <> list.map(other_arguments, fn(argument) {
                          argument.0
                        })
                        |> list.unique
                        |> string.join(",")
                          <> ")",
                        [get_generated_module_name(module.path)],
                        other_arguments,
                      )
                  }
                }
                Error(_) -> {
                  let parameters = case type_ {
                    glance.NamedType(parameters:, ..) -> parameters
                    _ -> []
                  }

                  let function =
                    justin.snake_case(source.definition.name)
                    <> case parameters {
                      [] -> ""
                      _ ->
                        "_"
                        <> list.map(parameters, fn(parameter) {
                          case parameter {
                            glance.NamedType(name:, ..) ->
                              justin.snake_case(name)
                            _ -> ""
                          }
                        })
                        |> string.join("_")
                    }
                    <> "_json_decoder"
                  GeneratedCode(function <> "()", [module.path], [
                    #(
                      function,
                      "fn() -> decode.Decoder("
                        <> module_name_for_path(module.name)
                        <> source.definition.name
                        <> case parameters {
                        [] -> ""
                        _ ->
                          "("
                          <> list.map(parameters, fn(parameter) {
                            case parameter {
                              glance.NamedType(name:, ..) -> name
                              _ -> ""
                            }
                          })
                          |> string.join(",")
                          <> ")"
                      }
                        <> ")",
                    ),
                  ])
                }
              }
          }
        }
      }
    Error(_) -> {
      let parameters = case type_ {
        glance.NamedType(parameters:, ..) -> parameters
        _ -> []
      }

      let function =
        justin.snake_case(case type_ {
          glance.NamedType(name:, ..) -> name
          _ -> ""
        })
        <> case parameters {
          [] -> variable
          _ ->
            "_"
            <> list.map(parameters, fn(parameter) {
              case parameter {
                glance.NamedType(name:, ..) -> justin.snake_case(name)
                _ -> ""
              }
            })
            |> string.join("_")
        }
        <> "_json_decoder"
      GeneratedCode(function <> "()", [], [
        #(function, ""),
      ])
    }
  }
}

fn get_variant_zero_value(
  config: Config,
  ctx: BuildContext,
  variant: glance.Variant,
  module: Module,
  variant_path: Set(glance.Variant),
) -> Result(GeneratedCode, Nil) {
  use <- bool.guard(set.contains(variant_path, variant), Error(Nil))

  let variant_path = set.insert(variant_path, variant)

  let output = ""

  let fields =
    list.try_map(variant.fields, fn(field) {
      case field.item {
        glance.VariableType(..) -> Error(Nil)
        _ -> {
          let zero =
            get_zero_value(
              config,
              ctx,
              field.item,
              module,
              module,
              variant_path,
            )

          case zero {
            Ok(zero) ->
              Ok(GeneratedCode(
                case field {
                  glance.LabelledVariantField(label:, ..) -> label <> ":"
                  glance.UnlabelledVariantField(..) -> ""
                }
                  <> zero.code,
                zero.imports,
                zero.arguments,
              ))
            Error(_) -> Error(Nil)
          }
        }
      }
    })

  case fields {
    Ok(fields) -> {
      let output =
        output
        <> module_name_for_path(module.name)
        <> variant.name
        <> case list.is_empty(fields) {
          False -> {
            let parameters =
              list.map(fields, fn(field) { field.code })
              |> string.join(",")

            "(" <> parameters <> ")"
          }
          _ -> ""
        }

      Ok(GeneratedCode(
        output,
        list.map(fields, fn(field) { field.imports })
          |> list.fold([], fn(acc, imports) { list.append(acc, imports) }),
        list.map(fields, fn(field) { field.arguments })
          |> list.fold([], fn(acc, arguments) { list.append(acc, arguments) }),
      ))
    }
    Error(_) -> Error(Nil)
  }
}

fn get_zero_value(
  config: Config,
  ctx: BuildContext,
  type_: glance.Type,
  current_module: Module,
  original_module: Module,
  variant_path: Set(glance.Variant),
) -> Result(GeneratedCode, Nil) {
  let is_prelude = inspect.is_prelude_type(ctx, type_, current_module)

  case type_ {
    glance.NamedType(name:, ..) -> {
      case name, is_prelude {
        "Int", True -> Ok(GeneratedCode("0", [], []))
        "Float", True -> Ok(GeneratedCode("0", [], []))
        "Bool", True -> Ok(GeneratedCode("False", [], []))
        "String", True -> Ok(GeneratedCode("\"\"", [], []))
        "List", True -> Ok(GeneratedCode("[]", [], []))
        _, _ ->
          get_zero_value_generic(
            config,
            ctx,
            type_,
            current_module,
            original_module,
            variant_path,
          )
      }
    }
    glance.TupleType(elements:, ..) -> {
      let codes =
        list.try_map(elements, fn(element) {
          get_zero_value(
            config,
            ctx,
            element,
            current_module,
            original_module,
            variant_path,
          )
        })

      case codes {
        Ok(codes) ->
          Ok(GeneratedCode(
            "#("<> codes |> list.map(fn(code) { code.code }) |> string.join(",")
              <> ")",
            list.map(codes, fn(code) { code.imports })
              |> list.fold([], fn(acc, imports) { list.append(acc, imports) }),
            list.map(codes, fn(code) { code.arguments })
              |> list.fold([], fn(acc, arguments) {
                list.append(acc, arguments)
              }),
          ))
        Error(_) -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn get_zero_value_generic(
  config: Config,
  ctx: BuildContext,
  type_: glance.Type,
  current_module: Module,
  original_module: Module,
  variant_path: Set(glance.Variant),
) -> Result(GeneratedCode, Nil) {
  case
    virtual_type_definition(
      inspect.find_type_definition(ctx, type_, current_module),
      ctx,
      type_,
      current_module,
    )
  {
    Ok(type_defintion) ->
      case type_defintion {
        inspect.TypeAlias(source:, module:) -> {
          get_zero_value(
            config,
            ctx,
            source.definition.aliased,
            module,
            original_module,
            variant_path,
          )
        }
        inspect.CustomType(source:, module:) -> {
          let custom_zero_values = [
            CustomZeroValue(
              type_name: "Option",
              module_path: "gleam/option",
              zero: fn(_, _, _, _) {
                Ok(GeneratedCode("option.None", ["gleam/option"], []))
              },
            ),
          ]

          let decoder =
            list.find_map(
              list.append(
                custom_zero_values,
                list.map(config.custom_codecs, fn(codec) {
                  CustomZeroValue(
                    type_name: codec.type_name,
                    module_path: codec.module_path,
                    zero: codec.zero,
                  )
                }),
              ),
              fn(custom_decoder) {
                case
                  source.definition.name == custom_decoder.type_name
                  && module.path == custom_decoder.module_path
                {
                  True -> Ok(custom_decoder.zero)
                  _ -> Error(Nil)
                }
              },
            )

          case decoder {
            Ok(decode) -> decode(ctx, type_, current_module, original_module)
            _ -> {
              case source.definition.opaque_ {
                True -> Error(Nil)
                _ ->
                  list.find_map(source.definition.variants, fn(variant) {
                    get_variant_zero_value(
                      config,
                      ctx,
                      variant,
                      module,
                      variant_path,
                    )
                  })
              }
            }
          }
        }
      }
    Error(_) -> Error(Nil)
  }
}

fn virtual_type_definition(
  result: Result(inspect.TypeDefinition, Nil),
  ctx: BuildContext,
  type_: glance.Type,
  current_module: Module,
) -> Result(inspect.TypeDefinition, Nil) {
  case result {
    Ok(_) -> result
    Error(_) -> {
      case type_ {
        glance.NamedType(name:, module:, ..) -> {
          let is_prelude = inspect.is_prelude_type(ctx, type_, current_module)

          case name, module, is_prelude {
            "Result", None, True -> {
              Ok(inspect.CustomType(
                glance.Definition(
                  [],
                  glance.CustomType(
                    glance.Span(0, 0),
                    "Result",
                    glance.Public,
                    False,
                    ["a", "b"],
                    [
                      glance.Variant(
                        "Ok",
                        [
                          glance.UnlabelledVariantField(glance.VariableType(
                            glance.Span(0, 0),
                            "a",
                          )),
                        ],
                        [],
                      ),
                      glance.Variant(
                        "Error",
                        [
                          glance.UnlabelledVariantField(glance.VariableType(
                            glance.Span(0, 0),
                            "b",
                          )),
                        ],
                        [],
                      ),
                    ],
                  ),
                ),
                module.Module(..current_module, name: ""),
              ))
            }
            _, _, _ -> result
          }
        }
        _ -> result
      }
    }
  }
}

fn module_name_for_path(name: String) {
  case name {
    "" -> ""
    _ -> name <> "."
  }
}
