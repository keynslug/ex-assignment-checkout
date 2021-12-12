defmodule Checkout.MixProject do
  use Mix.Project

  def project do
    [
      app: :checkout,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:typed_struct, "~> 0.2"},
      {:ratio, "~> 3.0"},

      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
