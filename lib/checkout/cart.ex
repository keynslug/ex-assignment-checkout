defmodule Checkout.Cart do
  @moduledoc """
  A cart representing ongoing purchase.

  One can add products to a cart (but not remove from it for the time being).
  A cart may have arbitrary number of `Checkout.Rule`s attached to it which are evaluated when
  some product is added to the cart. This usually results in discounts being applied to the
  purchase.
  """

  use TypedStruct

  alias Checkout.Rule

  @type item() :: Checkout.Product.t() | Checkout.Discount.t()
  @type rule() :: Rule.t()

  typedstruct do
    field :items, [item()], default: []
    field :rules, [rule()], default: []
    field :price, Checkout.amount(), default: 0
  end

  alias __MODULE__

  @doc """
  Create empty cart, optionally with a set of rules.
  """
  @spec empty([Rule.t()]) :: t()
  def empty(rules \\ []) do
    %Cart{rules: rules}
  end

  @doc """
  Add a product or a set of them in the cart, evaluating rules in the process.
  """
  @spec add(t(), Checkout.Product.t() | [Checkout.Product.t()]) :: t()
  def add(%Cart{} = cart, products) when is_list(products) do
    Enum.reduce(products, cart, fn p, cart -> add(cart, p) end)
  end

  def add(%Cart{items: items, rules: rules, price: price} = cart, product) do
    %Cart{cart |
      items: [product | items],
      rules: Enum.map(rules, &Rule.apply(&1, product)),
      price: price + product.price
    }
  end

  @doc """
  Compute cart total amount, taking into account any applied discounts.
  """
  @spec total(t()) :: Checkout.amount()
  def total(%Cart{} = cart) do
    discounts = cart.rules |> Enum.map(&Rule.total/1) |> Enum.sum()
    cart.price + discounts
  end

end
