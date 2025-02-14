defmodule EctoCommand.OpenApi.Type do
  @moduledoc false

  def uuid(options \\ []) do
    [format: :uuid, description: "UUID", example: "defa2814-3686-4a73-9f64-a17cdfd7f1a1"] ++ options
  end

  def enum(values, options \\ []) do
    [example: List.first(values)] ++ options
  end

  def datetime(options \\ []) do
    [format: :"date-time", example: "2023-04-03T10:21:00Z"] ++ options
  end

  def date(options \\ []) do
    [format: :date, example: "2023-04-03"] ++ options
  end

  def boolean(options \\ []) do
    [example: true] ++ options
  end

  def email(options \\ []) do
    [format: :email, description: "Email", example: "user@domain.com"] ++ options
  end

  def phone(options \\ []) do
    [format: :telephone, description: "Telephone", example: "(425) 123-4567"] ++ options
  end
end
