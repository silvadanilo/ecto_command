defmodule CommandEx.Middleware.Audit do
  @moduledoc false

  #FIXME:! implement interface

  @doc false
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts, module: __MODULE__] do
      @middlewares module
      @commandex_middleware_audit_options opts
      # @before_compile module
    end
  end

  def before_execution(command) do
    IO.inspect(command, label: "middleware")
  end

  # defmacro __before_compile__(_env) do
  #   quote unquote: false do
  #   end
  # end
end
