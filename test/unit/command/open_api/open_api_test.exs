defmodule Unit.CommandEx.OpenApi.OpenApiTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use CommandEx.Test.CommandCase

  defmodule Sample do
    @moduledoc false

    use CommandEx.Command
    use CommandEx.OpenApi, title: "Sample"

    command do
      field :id, :string, doc: Type.uuid()
      field :name, :string, required: true, length: [min: 2, max: 255], doc: [example: "Mario"]
      field :email, :string, required: true, format: ~r/@/, length: [min: 6], doc: Type.email()
      field :phone, :string, length: [min: 9], doc: Type.phone()
      field :extension, :string, required: false, length: [is: 3], doc: [example: "png"]

      field :mime_type, :string,
        required: true,
        inclusion: ["image/jpeg", "image/png"],
        doc: Type.enum(["image/jpeg", "image/png"])

      field :count, :integer, required: true, number: [greater_than_or_equal_to: 18, less_than: 100]
      field :an_integer_a, :integer, number: [equal_to: 20]
      field :an_integer_b, :integer, number: [not_equal_to: 20]
      field :an_integer_c, :integer, number: [greater_than: 18, less_than_or_equal_to: 100]
      field :type_id, :string
      field :accepts, :boolean, doc: Type.boolean()
      field :folder_id, :string, change: &String.valid?/1
      field :triggered_by, :map, internal: true
      field :uploaded_by, :string, internal: true
      field :uploaded_at, :utc_datetime, doc: Type.datetime()
    end
  end

  test "all properties docs are generated correctly" do
    assert %{
             accepts: %OpenApiSpex.Schema{example: true, type: :boolean},
             an_integer_a: %OpenApiSpex.Schema{
               exclusiveMaximum: false,
               exclusiveMinimum: false,
               maximum: 20,
               minimum: 20,
               type: :integer
             },
             an_integer_b: %OpenApiSpex.Schema{
               exclusiveMaximum: true,
               exclusiveMinimum: true,
               maximum: 20,
               minimum: 20,
               type: :integer
             },
             an_integer_c: %OpenApiSpex.Schema{
               exclusiveMaximum: false,
               exclusiveMinimum: true,
               maximum: 100,
               minimum: 18,
               type: :integer
             },
             count: %OpenApiSpex.Schema{
               exclusiveMaximum: true,
               exclusiveMinimum: false,
               maximum: 100,
               minimum: 18,
               type: :integer
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
             folder_id: %OpenApiSpex.Schema{type: :string},
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
             type_id: %OpenApiSpex.Schema{type: :string},
             uploaded_at: %OpenApiSpex.Schema{
               example: "2023-04-03T10:21:00Z",
               format: :"date-time",
               type: :utc_datetime
             }
           } == Sample.schema().properties
  end

  test "required fields list is generated correctly" do
    assert [:name, :email, :mime_type, :count] == Sample.schema().required
  end

  test "title and type are correctly set thanks tu the use options" do
    assert %OpenApiSpex.Schema{title: "Sample", type: :object} = Sample.schema()
  end

  test "fields flagged as internal do not appear in the generated documentation" do
    schema = Sample.schema()

    refute Map.has_key?(schema.properties, :triggered_by)
    refute Map.has_key?(schema.properties, :uploaded_by)
  end
end
