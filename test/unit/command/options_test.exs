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

    test "a field with :internal could be set by set function" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      defmodule module_name do
        use CommandEx.Command, resource_type: "Sample", resource_id: :id

        command do
          field :name, :string
          field :surname, :string, internal: true
        end

        def set(:surname, changeset, params) do
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
        field :name, :string, trim: true
        field :surname, :string, trim: false
      end

      assert {:ok, %{name: "foo", surname: "  bar  "}} = module_name.new(%{name: "  foo  ", surname: "  bar  "})
    end

    test "only :string fields could have the :trim option" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      assert_raise(ArgumentError, ~r/with string fields/, fn ->
        define_a_module_with_fields module_name do
          field :age, :integer, trim: true
        end
      end)
    end
  end
end
