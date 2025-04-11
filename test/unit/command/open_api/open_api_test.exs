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
      param :hidden_field, :string, required: true, inclusion: ["a", "b"], doc: false
      param :numeric_id, :id
      param :name, :string, required: true, length: [min: 2, max: 255], doc: [example: "Mario"]
      param :email, :string, required: true, format: ~r/@/, length: [min: 6], doc: Type.email()
      param :phone, :string, length: [min: 9], doc: Type.phone()
      param :extension, :string, required: false, length: [is: 3], doc: [example: "png"]

      param :mime_type, :string,
        required: true,
        inclusion: ["image/jpeg", "image/png"]

      param :an_enum, Ecto.Enum, values: [:a, :b]
      param :an_enum_stored_as_int, Ecto.Enum, values: [a: 1, b: 2]

      param :count, :integer, required: true, number: [greater_than_or_equal_to: 18, less_than: 100]
      param :an_integer_a, :integer, number: [equal_to: 20]
      param :an_integer_b, :integer, number: [not_equal_to: 20]
      param :an_integer_c, :integer, number: [greater_than: 18, less_than_or_equal_to: 100], doc: [example: 30]
      param :a_float, :float, number: [greater_than: 10, less_than_or_equal_to: 100]
      param :type_id, :string
      param :accepts, :boolean, default: false
      param :folder_id, :string, change: &String.valid?/1, doc: [example: "a_folder_id"]
      param :uploaded_at, :utc_datetime
      param :a_date, :date
      param :a_list_of_strings_a, {:array, :string}, default: []
      param :a_list_of_strings_b, {:array, :string}, doc: [description: "A list of strings A"]
      param :a_list_of_strings_c, {:array, :string}, subset: ["a", "b", "c"], doc: [description: "A list of strings B"]
      param :a_list_of_enums, {:array, Ecto.Enum}, values: [:a, :b, :c], doc: [description: "A list of enums"]
      param :a_map, :map, doc: [description: "A map"], default: %{}
      param :a_map_with_int_values, {:map, :integer}, doc: [description: "A map with integer values"], default: %{a: 1}

      internal :triggered_by, :map
      internal :uploaded_by, :string
    end
  end

  test "all properties docs are generated correctly" do
    assert %{
             accepts: %OpenApiSpex.Schema{example: false, type: :boolean, default: false},
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
             folder_id: %OpenApiSpex.Schema{type: :string, example: "a_folder_id"},
             id: %OpenApiSpex.Schema{
               description: "UUID",
               example: "02ef9c5f-29e6-48fc-9ec3-7ed57ed351f6",
               format: :uuid,
               type: :string
             },
             numeric_id: %OpenApiSpex.Schema{example: 10, type: :integer},
             mime_type: %OpenApiSpex.Schema{enum: ["image/jpeg", "image/png"], example: "image/jpeg", type: :string},
             name: %OpenApiSpex.Schema{example: "Mario", maxLength: 255, minLength: 2, type: :string},
             phone: %OpenApiSpex.Schema{
               description: "Telephone",
               example: "(425) 123-4567",
               format: :telephone,
               minLength: 9,
               type: :string
             },
             type_id: %OpenApiSpex.Schema{type: :string, example: ""},
             uploaded_at: %OpenApiSpex.Schema{
               example: "2020-04-20T16:20:00Z",
               format: :"date-time",
               type: :string
             },
             a_date: %OpenApiSpex.Schema{type: :string, format: :date, example: "2020-04-20"},
             a_list_of_enums: %OpenApiSpex.Schema{
               type: :array,
               items: [%OpenApiSpex.Schema{enum: ["a", "b", "c"], type: :string, example: "a"}],
               example: ["a", "b"],
               description: "A list of enums"
             },
             a_list_of_strings_a: %OpenApiSpex.Schema{
               type: :array,
               items: [%OpenApiSpex.Schema{type: :string, example: ""}],
               default: [],
               example: []
             },
             a_list_of_strings_b: %OpenApiSpex.Schema{
               type: :array,
               items: [%OpenApiSpex.Schema{type: :string, example: ""}],
               description: "A list of strings A",
               example: [""]
             },
             a_list_of_strings_c: %OpenApiSpex.Schema{
               type: :array,
               items: [%OpenApiSpex.Schema{enum: ["a", "b", "c"], type: :string, example: "a"}],
               example: ["a", "b"],
               description: "A list of strings B"
             },
             an_enum: %OpenApiSpex.Schema{enum: ["a", "b"], type: :string, example: "a"},
             an_enum_stored_as_int: %OpenApiSpex.Schema{enum: ["a", "b"], type: :string, example: "a"},
             a_map: %OpenApiSpex.Schema{
               type: :object,
               properties: %{},
               description: "A map",
               default: %{},
               example: %{}
             },
             a_map_with_int_values: %OpenApiSpex.Schema{
               type: :object,
               properties: %{},
               description: "A map with integer values",
               default: %{a: 1},
               example: %{a: 1}
             }
           } == Sample.schema().properties

    refute Map.has_key?(Sample.schema().properties, :hidden_field)
  end

  test "example is generated accordingly to properties" do
    assert %{
             a_date: "2020-04-20",
             a_float: 55.5,
             a_list_of_enums: ["a", "b"],
             a_list_of_strings_a: [],
             a_list_of_strings_b: [""],
             a_list_of_strings_c: ["a", "b"],
             a_map: %{},
             a_map_with_int_values: %{a: 1},
             accepts: false,
             an_enum: "a",
             an_enum_stored_as_int: "a",
             an_integer_a: 20,
             an_integer_b: 21,
             an_integer_c: 30,
             count: 58,
             email: "user@domain.com",
             extension: "png",
             folder_id: "a_folder_id",
             id: "02ef9c5f-29e6-48fc-9ec3-7ed57ed351f6",
             numeric_id: 10,
             mime_type: "image/jpeg",
             name: "Mario",
             phone: "(425) 123-4567",
             type_id: "",
             uploaded_at: "2020-04-20T16:20:00Z"
           } == Sample.schema().example

    refute Map.has_key?(Sample.schema().example, :hidden_field)
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
