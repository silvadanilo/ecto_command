defmodule Unit.CommandEx.Command.ExecutionTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use CommandEx.Test.CommandCase

  describe "execute/1 function" do
    test "execute is called only when the command is valid" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      defmodule module_name do
        use CommandEx.Command

        command do
          field :name, :string, required: true
          field :surname, :string, required: true
        end

        def execute(%__MODULE__{} = _command) do
          :executed
        end
      end

      assert :executed = module_name.execute(%{name: "foo", surname: "bar"})
      assert {:error, %Ecto.Changeset{valid?: false}} = module_name.execute(%{})
    end
  end
end
