defmodule Unit.CommandEx.Command.ValidatorsTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use CommandEx.Test.CommandCase

  describe "all ecto validators are supported" do
    test "change" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :name, :string, change: &unquote(__MODULE__).always_invalid/2

        field :surname, :string, change: {{:my_validator, [min: 2]}, &unquote(__MODULE__).always_valid/2}
      end

      assert [surname: {:my_validator, [min: 2]}] == defined_validators(module_name),
             "just surname has stored metadata"

      assert %{name: ["data is not valid"]} ==
               errors_on_execution(module_name, %{name: "foo", surname: "bar"})
    end

    test "acceptance" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :terms_and_condition, :boolean, acceptance: true
      end

      assert [terms_and_condition: {:acceptance, []}] == defined_validators(module_name)

      assert %{terms_and_condition: ["must be accepted"]} ==
               errors_on_execution(module_name, %{terms_and_condition: false})

      assert %{} == errors_on_execution(module_name, %{terms_and_condition: true})
    end

    test "confirmation" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :email, :string, confirmation: true
        field :email_confirmation, :string
      end

      assert [email: {:confirmation, []}] == defined_validators(module_name)

      assert %{} ==
               errors_on_execution(module_name, %{
                 email: "foo@bar.it",
                 email_confirmation: "foo@bar.it"
               })

      assert %{email_confirmation: ["does not match confirmation"]} ==
               errors_on_execution(module_name, %{
                 email: "foo@bar.it",
                 email_confirmation: "not_matching@email"
               })
    end

    test "exclusion" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :role, :string, exclusion: ["admin"]
      end

      assert [role: {:exclusion, ["admin"]}] == defined_validators(module_name)
      assert %{} == errors_on_execution(module_name, %{role: "user"})
      assert %{role: ["is reserved"]} == errors_on_execution(module_name, %{role: "admin"})
    end

    test "format" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :email, :string, format: ~r/@/
      end

      assert [email: {:format, ~r/@/}] == defined_validators(module_name)
      assert %{} == errors_on_execution(module_name, %{email: "foo@bar.com"})
      assert %{email: ["has invalid format"]} == errors_on_execution(module_name, %{email: "foo"})
    end

    test "inclusion" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :cardinal_direction, :string, inclusion: ["north", "east", "south", "west"]
      end

      assert [cardinal_direction: {:inclusion, ["north", "east", "south", "west"]}] ==
               defined_validators(module_name)

      assert %{} == errors_on_execution(module_name, %{cardinal_direction: "north"})

      assert %{cardinal_direction: ["is invalid"]} ==
               errors_on_execution(module_name, %{cardinal_direction: "foobar"})
    end

    test "length" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :name, :string, length: [min: 3, max: 10]
      end

      assert [name: {:length, [min: 3, max: 10]}] == defined_validators(module_name)
      assert %{} == errors_on_execution(module_name, %{name: "foobar"})

      assert %{name: ["should be at least 3 character(s)"]} ==
               errors_on_execution(module_name, %{name: "f"})

      assert %{name: ["should be at most 10 character(s)"]} ==
               errors_on_execution(module_name, %{name: "foobarfoobar"})
    end

    test "number" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :age, :integer, number: [greater_than_or_equal_to: 18, less_than: 100]
      end

      assert [age: {:number, [greater_than_or_equal_to: 18, less_than: 100]}] ==
               defined_validators(module_name)

      assert %{} == errors_on_execution(module_name, %{age: 20})

      assert %{age: ["must be greater than or equal to 18"]} ==
               errors_on_execution(module_name, %{age: 12})

      assert %{age: ["must be less than 100"]} == errors_on_execution(module_name, %{age: 180})
    end

    test "required" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :name, :string, required: true
      end

      assert [] == defined_validators(module_name)
      assert %{} == errors_on_execution(module_name, %{name: "foobar"})
      assert %{name: ["can't be blank"]} == errors_on_execution(module_name, %{})
      assert %{name: ["can't be blank"]} == errors_on_execution(module_name, %{name: nil})
      assert %{name: ["can't be blank"]} == errors_on_execution(module_name, %{name: ""})
    end

    test "subset" do
      module_name = String.to_atom("Sample#{:rand.uniform(999_999)}")

      define_a_module_with_fields module_name do
        field :lottery_numbers, {:array, :integer}, subset: 0..99
      end

      assert [{:lottery_numbers, {:subset, 0..99}}] == defined_validators(module_name)
      assert %{} == errors_on_execution(module_name, %{lottery_numbers: [2, 38, 47]})

      assert %{lottery_numbers: ["has an invalid entry"]} ==
               errors_on_execution(module_name, %{lottery_numbers: [99, 109, 408]})
    end
  end

  defp errors_on_execution(module_name, params) do
    params
    |> module_name.changeset()
    |> errors_on()
  end

  defp defined_validators(module_name) do
    %{}
    |> module_name.changeset()
    |> Ecto.Changeset.validations()
  end

  def always_invalid(field, _value), do: [{field, "data is not valid"}]
  def always_valid(_field, _value), do: []
end
