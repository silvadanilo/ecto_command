defmodule Unit.EctoCommand.CreationTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use EctoCommand.Test.CommandCase

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

    test "a param could have subparams" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        embeds_one :address, Address do
          param :street, :string
          param :city, :string
          param :zip, :string
        end
      end

      address_module = String.to_atom("Elixir.#{module_name}.Address")

      assert {:ok,
              struct!(module_name, %{
                address:
                  struct!(address_module, %{
                    street: "piazzale loreto",
                    city: "it/milano",
                    zip: "20142"
                  })
              })} == module_name.new(%{address: %{street: "piazzale loreto", city: "it/milano", zip: "20142"}})
    end

    test "when a subparam is invalid an invalid changeset is returned" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        embeds_one :address, Address do
          param :street, :string, required: true, length: [min: 10]
          param :city, :string, required: true
          param :zip, :string
        end
      end

      assert {:error, changeset} = module_name.new(%{address: %{street: "foo"}})

      assert %{address: %{city: ["can't be blank"], street: ["should be at least 10 character(s)"]}} ==
               errors_on(changeset)
    end

    test "an already existing module could be embedded" do
      embedded_module = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields embedded_module do
        param :street, :string, required: true, length: [min: 10]
        param :city, :string, required: true
        param :zip, :string
      end

      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        embeds_one :address, embedded_module
      end

      assert {:error, changeset} = module_name.new(%{address: %{street: "foo"}})

      assert %{address: %{city: ["can't be blank"], street: ["should be at least 10 character(s)"]}} ==
               errors_on(changeset)
    end
  end
end
