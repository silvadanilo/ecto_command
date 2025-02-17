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
  end

  test "example_for/1 returns nil in all other cases" do
    assert nil == Type.example_for(%Schema{})
  end
end
