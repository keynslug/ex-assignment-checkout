defmodule Checkout do
  @moduledoc """
  A part of hypothetical checkout system.
  """

  @typedoc "Amount of money, in minor currency units (e.g. pences)"
  @type amount() :: integer()

  defmodule Product do
    @moduledoc "A purchasable product"

    use TypedStruct

    @typedoc "Short code uniquely identifying a product"
    @type code() :: String.t()

    @typedoc "Price of a single product"
    @type price() :: Checkout.amount()

    typedstruct do
      field :code, code(), enforce: true
      field :name, String.t(), default: "<empty>"
      field :price, price(), default: 0
    end
  end

  defmodule Discount do
    @moduledoc "A discount applied to some purchase"

    use TypedStruct

    typedstruct do
      field :name, String.t(), default: "<empty>"
      field :amount, Checkout.amount(), default: 0
    end
  end

end
