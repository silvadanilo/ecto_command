defmodule Unit.EctoCommand.Middleware.PipelineTest do
  @moduledoc false

  use ExUnit.Case, async: true

  defmodule SampleCommand do
    defstruct []

    def execute(%SampleCommand{} = _command) do
      {:ok, :result}
    end
  end

  alias EctoCommand.Middleware.Pipeline
  alias Unit.EctoCommand.Middleware.PipelineTest.SampleCommand

  doctest EctoCommand.Middleware.Pipeline, import: true
end
