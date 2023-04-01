defmodule CommandExTest do
  use ExUnit.Case
  doctest CommandEx

  test "greets the world" do
    assert CommandEx.hello() == :world
  end
end
