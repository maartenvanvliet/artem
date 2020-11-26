defmodule ExGql.MixProject do
  use Mix.Project

  @url "https://github.com/maartenvanvliet/artem"

  def project do
    [
      app: :artem,
      version: "1.0.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Artem",
      description: "Artem is a library to help testing Absinthe documents",
      package: [
        maintainers: ["Maarten van Vliet"],
        licenses: ["MIT"],
        links: %{"GitHub" => @url},
        files: ~w(LICENSE README.md lib mix.exs)
      ],
      docs: [
        main: "Artem",
        canonical: "http://hexdocs.pm/artem",
        source_url: @url
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:absinthe, "~> 1.5"},
      {:ex_doc, "~> 0.22", only: [:dev, :test]},
      {:benchee, "~> 1.0", only: [:dev, :test]}
    ]
  end
end
