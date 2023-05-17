# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule Unit.EctoCommand.ExtraValidatorsTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use EctoCommand.Test.CommandCase

  test "is it possible to define an extra validator function" do
    module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

    define_a_module_with_fields module_name do
      param :name, :string
      param :surname, :string
      validate_with(&Unit.EctoCommand.ExtraValidatorsTest.custom_validation/2)
    end

    changeset = module_name.changeset(%{name: "foo", surname: "bar"})
    assert %{name: ["data is not valid"]} == errors_on(changeset)
  end

  test "is it possible to pass options to an extra validator function" do
    module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

    define_a_module_with_fields module_name do
      param :name, :string
      param :surname, :string

      validate_with(&Unit.EctoCommand.ExtraValidatorsTest.custom_validation/2,
        field: :name,
        message: "my custom message"
      )

      validate_with(&Unit.EctoCommand.ExtraValidatorsTest.custom_validation/2,
        field: :surname,
        message: "my custom message"
      )
    end

    changeset = module_name.changeset(%{name: "foo", surname: "bar"})
    assert %{name: ["my custom message"], surname: ["my custom message"]} == errors_on(changeset)
  end

  def custom_validation(changeset, opts \\ []) do
    message = opts[:message] || "data is not valid"
    field = opts[:field] || :name
    Ecto.Changeset.add_error(changeset, field, message)
  end
end
