defmodule Unit.CommandEx.Middleware.PipelineTest do
  @moduledoc false

  use ExUnit.Case, async: true

  defmodule SampleCommand do
    defstruct []

    def execute(%SampleCommand{} = _command) do
      {:ok, :result}
    end
  end

  alias CommandEx.Middleware.Pipeline
  alias Unit.CommandEx.Middleware.PipelineTest.SampleCommand

  doctest CommandEx.Middleware.Pipeline, import: true
end
