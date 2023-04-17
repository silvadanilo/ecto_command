defmodule EctoCommandTest do
  use ExUnit.Case
  doctest EctoCommand

  test "greets the world" do
    assert EctoCommand.hello() == :world
  end
end
