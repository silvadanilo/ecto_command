# EctoCommand

EctoCommand is a toolkit for mapping, validating, and executing commands received from any source.
It provides a simple and flexible way to define and execute commands in Elixir. With its support for validation, middleware, and automatic OpenAPI documentation generation, it's a valuable tool for building scalable and maintainable Elixir applications. We hope you find it useful!

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ecto_command` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_command, "~> 0.1.0"}
  ]
end
```

## Why Ecto?

"Ecto is also commonly used to map data from any source into Elixir structs, whether they are backed by a database or not."  
Based on this definition of the [Ecto](https://github.com/elixir-ecto/ecto) library **EctoCommand** utilizes the "embedded_schema" functionality to map input data into an elixir data structure to be used as a "command".  
**This means that EctoCommand is not tied to your persistence layer.**

As a result, you can easily convert data received from any source into a valid command struct, which can be executed easily. 
Additionally, you can also add functionality through middlewares to the execution pipeline.  

Here is an example:

```elixir
defmodule SampleCommand do
  use EctoCommand.Command

  command do
    param :id, :string
    param :name, :string, required: true, length: [min: 2, max: 255]
    param :email, :string, required: true, format: ~r/@/, length: [min: 6]
    param :count, :integer, required: true, number: [greater_than_or_equal_to: 18, less_than: 100]
    param :password, :string, required: true, length: [greater_than_or_equal_to: 8, less_than: 100], trim: true

    internal :hased_password, :string
  end

  def execute(%SampleCommand{} = command) do
    # ....
    :ok
  end

  def fill(:hased_password, _changeset, %{"password" => password}, _metadata) do
    :crypto.hash(:sha256, password) |> Base.encode64()
  end
end

:ok = SampleCommand.execute(%{id: "aa-bb-cc", name: "foobar", email: "foo@bar.com", count: 22, password: "mysecret"})

```

## Main goals and functionality of EctoCommand

- [An easy way to define the fields in a command (`param` macro).](#params-definition)
- [Provides a simple and compact way of specifying how these fields should be validated (`param` macro options).](#validations-and-constraints-definition)
- [Defining the fields that need to be part of the command but can't be set from the outside, they must be filled in from within the command (`internal` macro)](#internal-fields)
- [Validation of the params received from the outside](#validations)
- [Easy hooking of middleware to add functionality (like audit)](#using-middlewares-in-ectocommand)
- [Automatic generation of OpenApi documentation](#automated-generation-of-openapi-documentation)

## Params definition

To define the params that a command should accept we should use the macro `param`.
The `param` macro is based on the `field` macro of [Ecto.Schema](https://hexdocs.pm/ecto/Ecto.Schema.html) so it basically defines a field in the schema with a given name and type and it is possible to pass all the options supported also by the `field` macro.
Afterwards, each defined `param` is cast with the "external" data received

## Validations and constraints definition

In addition to those options, the `param` macro accepts a set of other options that indicates how external data for that field should be validated.
These options are applied on the intermediate Changeset that is created in order to validate data.
These options are mapped into `validate_*` methods of the [Ecto.Changeset](https://hexdocs.pm/ecto/Ecto.Changeset.html)
So, for example, if you want that command should have a "name" field that is required and it should have a precise length between 2 and 255 chars you could write:
```Elixir
param :name, :string, required: true, length: [min: 2, max: 255]
```

that it means that the command will have a `name` field, that field will be cast to a `string` type, and these functions will be called on the changeset:
```Elixir
changeset
|> validate_required([:name])
|> validate_length(:name, min: 2, max: 255)
```

for validators that accept both data and options, you could pass just data like:
```elixir
param :email, :string, format: ~r/@/
```
or data and options in this way:
```elixir
param :email, :string, format: {~r/@/, message: "my custom error message"}
```

## Internal fields

It could be that you need the command to have fields that are not fillable from outside, such as a "hased_password" field (like the example above)
or a "triggered_by" field that should be filled in based on the currently logged-in user (and we want to avoid that someone could submit the desired triggered_by user)  
For those cases you could use the `internal` macro:
```elixir
  command do
    param :password, :string, required: true, length: [greater_than_or_equal_to: 8, less_than: 100], trim: true
    internal :hased_password, :string
    internal :triggered_by, :string
  end

  def fill(:hased_password, _changeset, %{"password" => password}, _metadata) do
    :crypto.hash(:sha256, password) |> Base.encode64()
  end

  def fill(:triggered_by, _changeset, _params, %{"triggered_by": triggered_by}) do
    triggered_by
  end

  def fill(:triggered_by, changeset, _params, _metadata) do
    Ecto.Changeset.add_error(changeset, :triggered_by, "triggered_by metadata info is missing")
  end
```

Internal fields will be ignored during the "cast process". Instead, you will need to create a public `fill/4` function to populate them.  
The `fill/4` function takes four arguments: the name of the field, the current temporary changeset, the parameters received from external sources, and additional metadata.  
You can choose to return the value that will populate the field or the updated changeset. Both options are acceptable, but returning the changeset is particularly useful if you want to add errors to it.

## Validations 
FIXME

## Using Middlewares in EctoCommand
EctoCommand provides support for middlewares, which allow you to modify the behavior of a command before and/or after its execution. 
A middleware is a module that implements the EctoCommand.Middleware behavior. Here's how you can use middlewares in your EctoCommand project:

```elixir
defmodule MyApp.MyMiddleware do
  @behaviour EctoCommand.Middleware

  @impl true
  def before_execution(pipeline, _opts) do
    pipeline
    |> Pipeline.assign(:some_data, :some_value)
    |> Pipeline.update!(:command, fn command -> %{command | name: "updated-name"} end)
  end

  @impl true
  def after_execution(pipeline, _opts) do
    Logger.debug("Command executed successfully", command: pipeline.command, result: Pipeline.response(pipeline))
    pipeline
  end

  @impl true
  def after_failure(pipeline, _opts) do
    Logger.error("Command execution fails", command: pipeline.command, error: Pipeline.response(pipeline))
    pipeline
  end

  @impl true
  def invalid(pipeline, _opts) do
    Logger.error("invalid params received", params: pipeline.params, error: Pipeline.response(pipeline))
    pipeline
  end
end
```

Each method takes two arguments: an [EctoCommand.Pipeline](https://github.com/silvadanilo/ecto_command/blob/master/lib/ecto_command/middleware/pipeline.ex) structure and the options you set for that middleware.  
The method should return an EctoCommand.Pipeline structure.

- `before_execution/2` is executed before command execution, it is executed only if the command is valid. In this function you could, if you wish, also update the command that will be executed.
- `after_execution/2` is executed after command successfully execution. In this function you could, if you wish, also update the returned value.
- `after_failure/2` is executed after command successfully execution. In this function you could, if you wish, also update the returned value.
- `invalid/2` is executed when data to build the command is invalid. 

### Configuring Middlewares
There are two ways to specify which middleware should be executed:

1. **Global configuration:** 

You can set up a list of middleware to be executed for every command by adding the following to your application's configuration:

```elixir
config :ecto_command, :middlewares,
  {MyApp.MyFirstMiddleware, a_middleware_option: :foo},
  {MyApp.MySecondMiddleware, a_middleware_option: :bar}
```

2. **Command-level configuration:** 

You can also specify middleware to be executed for a specific command by adding the `use` directive in the command module:

```elixir
defmodule MyApp.MyCommand do
  use EctoCommand.Command
  use MyApp.MyFirstMiddleware, a_middleware_option: :foo
  use MyApp.MySecondMiddleware, a_middleware_option: :bar

  ....
end
```

In this case, the specified middleware is executed only for that particular command.


## Automated generation of OpenAPI documentation

EctoCommand has a built-in feature that automatically generates OpenAPI documentation based on the parameters and validation rules defined in your command modules.  
This can save you a significant amount of time and effort in writing and maintaining documentation, particularly if you have a large number of commands.  

To generate the OpenAPI schema, you can use the `EctoCommand.OpenApi` module:

```elixir
use EctoCommand.OpenApi
```

By default, the schema's title is the fully qualified domain name (FQDN) of the module, and the default type is `:object`. 
However, you can override the defaults by passing options to the `use` module:

```elixir
use EctoCommand.OpenApi, title: "CustomTitle", type: :object
```


Then in your controller you can simply pass your command module to the request body specs:
```elixir

defmodule MyAppWeb.PostController do
  use MyAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias MyApp.Commands.CreatePost

  operation :create_post,
    summary: "Create a Post",
    request_body: {"Post params", "application/json", CreatePost},
    responses: [
      ok: {"Post response", "application/json", []},
      bad_request: {"Post response", "application/json", []}
    ]
  def create_post(conn, params) do
    ...
  end
```

For more information on serving the Swagger UI, please refer to the readme of the [open-api-spex](https://github.com/open-api-spex/open_api_spex) library.

## Contributing
Contributions are always welcome! Please feel free to submit a pull request or create an issue if you find a bug or have a feature request.

## License
EctoCommand is released under the MIT License. See the LICENSE file for more information.


> Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
> and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
> be found at <https://hexdocs.pm/ecto_command>.
