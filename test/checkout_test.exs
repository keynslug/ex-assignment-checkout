defmodule CheckoutTest do
  use ExUnit.Case
  doctest Checkout

  alias Checkout.Cart
  alias Checkout.Rule
  alias Checkout.Rule.Condition
  alias Checkout.Rule.Discount

  @discount_100 Discount.absolute(-100)
  @discount_10p Discount.percents(-10)

  test "empty cart costs nothing" do
    cart = Cart.empty()
    assert_total cart, 0
  end

  test "empty cart w/ rules costs nothing" do
    cart = Cart.empty([
      %Rule{precondition: Condition.each(3), definition: @discount_100},
      %Rule{definition: Rule.bulk(@discount_10p)}
    ])
    assert_total cart, 0
  end

  defmodule PriceSheet do
    @moduledoc "Price sheet with 2 products as given in the assignment"

    alias Checkout.Product

    @spec lookup(Product.code()) :: Product.t()
    def lookup("GR1" = code), do: %Product{code: code, name: "Green tea", price: 311}
    def lookup("SR1" = code), do: %Product{code: code, name: "Strawberries", price: 500}
    def lookup("CF1" = code), do: %Product{code: code, name: "Coffee", price: 1123}
  end

  @rule_ceo Rule.new(
    "Buy a Green tea get one FREE!",
    Discount.percents(-100),
    precondition: Condition.product?("GR1") |> Condition.each(2)
  )

  @rule_coo Rule.new(
    "3+ Strawberries 4.5£ EACH!",
    Discount.absolute(-50),
    precondition: Condition.product?("SR1"),
    postcondition: Condition.over?(2)
  )

  @rule_cto Rule.new(
    "3+ Coffees 1/3 OFF ALL!",
    Rule.bulk(Discount.share(-1, 3)),
    precondition: Condition.product?("CF1"),
    postcondition: Condition.over?(2)
  )

  @doc "Rules with 3 different discounts as given in the assignment"
  @rules_execs [
    @rule_ceo,
    @rule_coo,
    @rule_cto
  ]

  test "GR1,SR1,GR1,GR1,CF1" do
    cart = cart_with(@rules_execs, ["GR1", "SR1", "GR1", "GR1", "CF1"])
    assert_total cart, 2245
  end

  test "GR1,GR1" do
    cart = cart_with(@rules_execs, ["GR1", "GR1"])
    assert_total cart, 311
  end

  test "SR1,SR1,GR1,SR1" do
    cart = cart_with(@rules_execs, ["SR1", "SR1", "GR1", "SR1"])
    assert_total cart, 1661
  end

  test "GR1,CF1,SR1,CF1,CF1" do
    cart = cart_with(@rules_execs, ["GR1", "CF1", "SR1", "CF1", "CF1"])
    assert_total cart, 3057
  end

  defp cart_with(rules, product_codes) do
    products = Enum.map(product_codes, &PriceSheet.lookup/1)
    cart = Cart.empty(rules) |> Cart.add(products)
    cart
  end

  defp assert_total(cart, expected) do
    total = Cart.total(cart)
    assert total == expected,
      "Expected cart to have amount #{expected}, got: #{total}\n" <>
      "Cart is: #{inspect(cart, pretty: true)}"
  end

end
