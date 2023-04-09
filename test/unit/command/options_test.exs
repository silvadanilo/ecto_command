defmodule Unit.CommandEx.Command.OptionsTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use CommandEx.Test.CommandCase

  describe ":internal option" do
    test "an internal field is not casted" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        param :name, :string
        internal :surname, :string
      end

      changeset = module_name.changeset(%{name: "foo", surname: "bar"})
      assert true == Map.has_key?(changeset.changes, :name)
      assert false == Map.has_key?(changeset.changes, :surname)
    end

    test "an internal field could be set by the 'fill/3' function" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      defmodule module_name do
        use CommandEx.Command, resource_type: "Sample", resource_id: :id

        command do
          param :name, :string
          internal :surname, :string
        end

        def fill(:surname, changeset, params) do
          "my custom set: #{changeset.changes.name} #{params["surname"]}"
        end
      end

      changeset = module_name.changeset(%{name: "foo", surname: "bar"})
      assert %{name: "foo", surname: "my custom set: foo bar"} == changeset.changes
    end
  end

  describe ":trim option" do
    test "a field with :trim option is trimmed" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        param :name, :string, trim: true
        param :surname, :string, trim: false
      end

      assert {:ok, %{name: "foo", surname: "  bar  "}} = module_name.new(%{name: "  foo  ", surname: "  bar  "})
    end

    test "only :string fields could have the :trim option" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      assert_raise(ArgumentError, ~r/with string fields/, fn ->
        define_a_module_with_fields module_name do
          param :age, :integer, trim: true
        end
      end)
    end
  end
end
