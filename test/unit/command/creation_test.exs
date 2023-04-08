defmodule Unit.CommandEx.Command.CreationTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use CommandEx.Test.CommandCase

  describe "new/1 function" do
    test "returns a valid command struct when there are not validations error" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        param :name, :string, required: true
        param :surname, :string, required: true
      end

      assert {:ok, struct!(module_name, %{name: "foo", surname: "bar"})} ==
               module_name.new(%{name: "foo", surname: "bar"})
    end

    test "returns an invalid changeset when there are validations error" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        param :name, :string, required: true, length: [min: 10, max: 99]
        param :surname, :string, required: true, length: [min: 10, max: 99]
        param :age, :integer, number: [greater_than_or_equal_to: 18]
      end

      assert {:error, changeset} = module_name.new(%{name: "foo", age: 15})

      assert %{
               age: ["must be greater than or equal to 18"],
               name: ["should be at least 10 character(s)"],
               surname: ["can't be blank"]
             } == errors_on(changeset)
    end
  end
end
