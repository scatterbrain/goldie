defmodule Goldie.Mixfile do
  use Mix.Project

  def project do
    [app: :goldie,
      version: "0.0.1",
      elixir: "~> 1.2",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps, 
      test_coverage: [tool: Coverex.Task]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ranch], 
      mod: {Goldie, []}    
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ranch, "~> 1.2"},
      #{:msgpax, "~> 0.8.2"},
      {:msgpack, git: "git://github.com/msgpack/msgpack-erlang.git", tag: "0.1.2"},
      {:graphmath, "~> 1.0.2" },      
      {:dialyxir, "~> 0.3", only: [:local]}, 
      {:dogma, "~> 0.1.0", only: [:local]}, 
      {:credo, "~> 0.3", only: [:local]}, 
      {:mock, "~> 0.1.1", only: :test}, 
      {:coverex, "~> 1.4.7", only: :test}
    ]
  end
end
