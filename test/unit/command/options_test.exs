defmodule Unit.CommandEx.Command.OptionsTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use CommandEx.Test.CommandCase

  describe ":internal option" do
    test "a field with :internal option is not casted" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :name, :string
        field :surname, :string, internal: true
      end

      changeset = module_name.changeset(%{name: "foo", surname: "bar"})
      assert true == Map.has_key?(changeset.changes, :name)
      assert false == Map.has_key?(changeset.changes, :surname)
    end
  end

  describe ":trim option" do
    test "a field with :trim option is trimmed" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :name, :string, trim: true
        field :surname, :string, trim: false
      end

      assert {:ok, %{name: "foo", surname: "  bar  "}} = module_name.new(%{name: "  foo  ", surname: "  bar  "})
    end
  end
end
