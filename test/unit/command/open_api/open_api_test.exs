defmodule Unit.EctoCommand.OpenApi.OpenApiTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use EctoCommand.Test.CommandCase

  defmodule Sample do
    @moduledoc false

    use EctoCommand
    use EctoCommand.OpenApi, title: "Sample"

    command do
      param :id, :string, doc: Type.uuid()
      param :name, :string, required: true, length: [min: 2, max: 255], doc: [example: "Mario"]
      param :email, :string, required: true, format: ~r/@/, length: [min: 6], doc: Type.email()
      param :phone, :string, length: [min: 9], doc: Type.phone()
      param :extension, :string, required: false, length: [is: 3], doc: [example: "png"]

      param :mime_type, :string,
        required: true,
        inclusion: ["image/jpeg", "image/png"],
        doc: Type.enum(["image/jpeg", "image/png"])

      param :an_enum, Ecto.Enum, values: [:a, :b]

      param :count, :integer, required: true, number: [greater_than_or_equal_to: 18, less_than: 100]
      param :an_integer_a, :integer, number: [equal_to: 20]
      param :an_integer_b, :integer, number: [not_equal_to: 20]
      param :an_integer_c, :integer, number: [greater_than: 18, less_than_or_equal_to: 100], doc: [example: 30]
      param :a_float, :float, number: [greater_than: 10, less_than_or_equal_to: 100]
      param :type_id, :string
      param :accepts, :boolean, default: false, doc: Type.boolean()
      param :folder_id, :string, change: &String.valid?/1
      param :uploaded_at, :utc_datetime, doc: Type.datetime()
      param :a_date, :date
      param :a_list_of_strings_a, {:array, :string}, default: []
      param :a_list_of_strings_b, {:array, :string}, doc: [description: "A list of strings A"]
      param :a_list_of_strings_c, {:array, :string}, subset: ["a", "b", "c"], doc: [description: "A list of strings B"]
      param :a_list_of_enums, {:array, Ecto.Enum}, values: [:a, :b, :c], doc: [description: "A list of enums"]

      internal :triggered_by, :map
      internal :uploaded_by, :string
    end
  end

  test "all properties docs are generated correctly" do
    assert %{
             accepts: %OpenApiSpex.Schema{example: true, type: :boolean, default: false},
             an_integer_a: %OpenApiSpex.Schema{
               exclusiveMaximum: false,
               exclusiveMinimum: false,
               maximum: 20,
               minimum: 20,
               type: :integer,
               example: 20
             },
             an_integer_b: %OpenApiSpex.Schema{type: :integer, not: %{enum: [20]}, example: 21},
             an_integer_c: %OpenApiSpex.Schema{
               exclusiveMaximum: false,
               exclusiveMinimum: true,
               maximum: 100,
               minimum: 18,
               type: :integer,
               example: 30
             },
             a_float: %OpenApiSpex.Schema{
               exclusiveMaximum: false,
               exclusiveMinimum: true,
               maximum: 100,
               minimum: 10,
               type: :number,
               example: 55.5
             },
             count: %OpenApiSpex.Schema{
               exclusiveMaximum: true,
               exclusiveMinimum: false,
               maximum: 100,
               minimum: 18,
               type: :integer,
               example: 58
             },
             email: %OpenApiSpex.Schema{
               description: "Email",
               example: "user@domain.com",
               format: :email,
               minLength: 6,
               pattern: ~r/@/,
               type: :string
             },
             extension: %OpenApiSpex.Schema{example: "png", maxLength: 3, type: :string},
             folder_id: %OpenApiSpex.Schema{type: :string, example: "string"},
             id: %OpenApiSpex.Schema{
               description: "UUID",
               example: "defa2814-3686-4a73-9f64-a17cdfd7f1a1",
               format: :uuid,
               type: :string
             },
             mime_type: %OpenApiSpex.Schema{enum: ["image/jpeg", "image/png"], example: "image/jpeg", type: :string},
             name: %OpenApiSpex.Schema{example: "Mario", maxLength: 255, minLength: 2, type: :string},
             phone: %OpenApiSpex.Schema{
               description: "Telephone",
               example: "(425) 123-4567",
               format: :telephone,
               minLength: 9,
               type: :string
             },
             type_id: %OpenApiSpex.Schema{type: :string, example: "string"},
             uploaded_at: %OpenApiSpex.Schema{
               example: "2023-04-03T10:21:00Z",
               format: :"date-time",
               type: :string
             },
             a_date: %OpenApiSpex.Schema{type: :string, format: :date, example: "2023-04-03"},
             a_list_of_enums: %OpenApiSpex.Schema{
               type: :array,
               items: [%OpenApiSpex.Schema{enum: ["a", "b", "c"], type: :string, example: "a"}],
               example: ["a", "b"],
               description: "A list of enums"
             },
             a_list_of_strings_a: %OpenApiSpex.Schema{
               type: :array,
               items: [%OpenApiSpex.Schema{type: :string, example: "string"}],
               default: [],
               example: []
             },
             a_list_of_strings_b: %OpenApiSpex.Schema{
               type: :array,
               items: [%OpenApiSpex.Schema{type: :string, example: "string"}],
               description: "A list of strings A",
               example: ["string"]
             },
             a_list_of_strings_c: %OpenApiSpex.Schema{
               type: :array,
               items: [%OpenApiSpex.Schema{enum: ["a", "b", "c"], type: :string, example: "a"}],
               example: ["a", "b"],
               description: "A list of strings B"
             },
             an_enum: %OpenApiSpex.Schema{enum: ["a", "b"], type: :string, example: "a"}
           } == Sample.schema().properties
  end

  test "example is generated accordingly to properties" do
    assert %{
             a_date: "2023-04-03",
             a_float: 55.5,
             a_list_of_enums: ["a", "b"],
             a_list_of_strings_a: [],
             a_list_of_strings_b: ["string"],
             a_list_of_strings_c: ["a", "b"],
             accepts: true,
             an_enum: "a",
             an_integer_a: 20,
             an_integer_b: 21,
             an_integer_c: 30,
             count: 58,
             email: "user@domain.com",
             extension: "png",
             folder_id: "string",
             id: "defa2814-3686-4a73-9f64-a17cdfd7f1a1",
             mime_type: "image/jpeg",
             name: "Mario",
             phone: "(425) 123-4567",
             type_id: "string",
             uploaded_at: "2023-04-03T10:21:00Z"
           } == Sample.schema().example
  end

  test "required fields list is generated correctly" do
    assert [:name, :email, :mime_type, :count] == Sample.schema().required
  end

  test "title and type are correctly set thanks to the use options" do
    assert %OpenApiSpex.Schema{title: "Sample", type: :object} = Sample.schema()
  end

  test "fields flagged as internal do not appear in the generated documentation" do
    schema = Sample.schema()

    refute Map.has_key?(schema.properties, :triggered_by)
    refute Map.has_key?(schema.properties, :uploaded_by)
  end
end
