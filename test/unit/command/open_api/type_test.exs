defmodule Unit.EctoCommand.OpenApi.TypeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias EctoCommand.OpenApi.Type
  alias OpenApiSpex.Schema

  describe "example_for/1 generates a valid example" do
    test "for arrays of enums" do
      assert [1, 2] == Type.example_for(%Schema{type: :array, items: [%{type: :integer, enum: [1, 2, 3]}]})
      assert ["a", "b"] == Type.example_for(%Schema{type: :array, items: [%{type: :string, enum: ["a", "b", "c"]}]})
    end

    test "for enums" do
      assert 1 == Type.example_for(%Schema{type: :integer, enum: [1, 2, 3]})
      assert "a" == Type.example_for(%Schema{type: :string, enum: ["a", "b", "c"]})
    end

    test "for integers" do
      assert 10 == Type.example_for(%Schema{type: :integer})
    end

    test "for integers with exclusive 'min' constraint" do
      schema = %Schema{type: :integer, exclusiveMinimum: true, minimum: 100}
      assert 101 == Type.example_for(schema)
    end

    test "for integers with exclusive 'max' constraint" do
      schema = %OpenApiSpex.Schema{type: :integer, exclusiveMaximum: true, maximum: 10}
      assert 9 == Type.example_for(schema)
    end

    test "for integers with exclusive 'min' and 'max' constraints" do
      schema = %OpenApiSpex.Schema{
        type: :integer,
        exclusiveMaximum: true,
        exclusiveMinimum: true,
        maximum: 10,
        minimum: 3
      }

      assert 6 == Type.example_for(schema)
    end

    test "for integers with inclusive 'min' constraint" do
      schema = %Schema{type: :integer, exclusiveMinimum: false, minimum: 100}
      assert 100 == Type.example_for(schema)
    end

    test "for integers with inclusive 'max' constraint" do
      schema = %OpenApiSpex.Schema{type: :integer, exclusiveMaximum: false, maximum: 10}
      assert 10 == Type.example_for(schema)
    end

    test "for integers with inclusive 'min' and 'max' constraints" do
      schema = %OpenApiSpex.Schema{
        type: :integer,
        exclusiveMaximum: false,
        exclusiveMinimum: false,
        maximum: 10,
        minimum: 5
      }

      assert 7 == Type.example_for(schema)
    end

    test "for numbers" do
      assert 10.0 == Type.example_for(%Schema{type: :number})
    end

    test "for numbers with exclusive 'min' constraint" do
      schema = %Schema{type: :number, exclusiveMinimum: true, minimum: 100.0}
      assert 101.0 == Type.example_for(schema)
    end

    test "for numbers with exclusive 'max' constraint" do
      schema = %OpenApiSpex.Schema{type: :number, exclusiveMaximum: true, maximum: 10.0}
      assert 9.0 == Type.example_for(schema)
    end

    test "for numbers with exclusive 'min' and 'max' constraints" do
      schema = %OpenApiSpex.Schema{
        type: :number,
        exclusiveMaximum: true,
        exclusiveMinimum: true,
        maximum: 10,
        minimum: 5
      }

      assert 7.5 == Type.example_for(schema)
    end

    test "for numbers with inclusive 'min' constraint" do
      schema = %Schema{type: :number, exclusiveMinimum: false, minimum: 100}
      assert 100.0 == Type.example_for(schema)
    end

    test "for numbers with inclusive 'max' constraint" do
      schema = %OpenApiSpex.Schema{type: :number, exclusiveMaximum: false, maximum: 10}
      assert 10.0 == Type.example_for(schema)
    end

    test "for numbers with inclusive 'min' and 'max' constraints" do
      schema = %OpenApiSpex.Schema{
        type: :number,
        exclusiveMaximum: false,
        exclusiveMinimum: false,
        maximum: 10,
        minimum: 9
      }

      assert 9.5 == Type.example_for(schema)
    end

    test "for booleans" do
      assert true == Type.example_for(%Schema{type: :boolean})
    end

    test "for dates" do
      assert "2023-04-03" == Type.example_for(%Schema{type: :string, format: :date})
    end

    test "for datetimes" do
      assert "2023-04-03T10:21:00Z" == Type.example_for(%Schema{type: :string, format: :"date-time"})
    end

    test "for UUIDs" do
      assert "defa2814-3686-4a73-9f64-a17cdfd7f1a1" == Type.example_for(%Schema{type: :string, format: :uuid})
    end

    test "for emails" do
      assert "user@domain.com" == Type.example_for(%Schema{type: :string, format: :email})
    end

    test "for passwords" do
      assert "Abcd123!!" == Type.example_for(%Schema{type: :string, format: :password})
    end

    test "for telephones" do
      assert "(425) 123-4567" == Type.example_for(%Schema{type: :string, format: :telephone})
    end

    test "for object" do
      schema = %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          active: %OpenApiSpex.Schema{type: :boolean, default: true, example: true},
          count: %OpenApiSpex.Schema{minimum: 10, exclusiveMinimum: true, type: :integer, example: 11},
          id: %OpenApiSpex.Schema{type: :string},
          name: %OpenApiSpex.Schema{type: :string},
          type: %OpenApiSpex.Schema{enum: ["a", "b"], type: :string, example: "a"},
          tags: %OpenApiSpex.Schema{type: :array, items: [%OpenApiSpex.Schema{type: :string, default: []}]},
          non_required_id: %OpenApiSpex.Schema{type: :string}
        }
      }

      assert %{
               active: true,
               count: 11,
               id: "string",
               name: "string",
               type: "a",
               tags: [],
               non_required_id: "string"
             } == Type.example_for(schema)
    end
  end

  test "example_for/1 returns nil in all other cases" do
    assert nil == Type.example_for(%Schema{})
  end
end
