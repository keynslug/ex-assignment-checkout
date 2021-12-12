defmodule Checkout.Rule do
  @moduledoc """
  A rule to evaluate on a cart, for example to produce specific discount.
  """

  use TypedStruct

  alias Checkout.Product

  @type discount() :: Discount.t() | bulk_discount()
  @type bulk_discount() :: {:bulk, Checkout.amount(), Discount.t()}

  typedstruct do
    @typedoc "Stateful rule for discount evaluation"

    field :name, String.t(), default: "<unnamed>"
    field :precondition, Condition.t() | nil
    field :definition, discount(), enforce: true
    field :postcondition, Condition.t() | nil
    field :active?, boolean(), default: false
    field :items, [Checkout.Cart.item()], default: []
  end

  alias __MODULE__

  defmodule Condition do
    @moduledoc """
    Functions to define complex conditions.
    """

    @typedoc "A (possibly complex) condition to check for a purchase, which may have state."
    @type t() ::
      :any
      | {:product, Product.code(), t()}
      | {:each, pos_integer(), integer(), t()}
      | {:over, pos_integer(), integer(), t()}

    @doc "Condition which always evaluates to true."
    @spec any?() :: t()
    def any? do
      :any
    end

    @doc "Condition which checks inner condition if specific product is added to a cart"
    @spec product?(t(), Product.code()) :: t()
    def product?(inner \\ any?(), code) do
      {:product, code, inner}
    end

    @doc "Condition which checks inner condition every `nth` added product"
    @spec each(t(), pos_integer()) :: t()
    def each(inner \\ any?(), nth) when is_integer(nth) and nth > 0 do
      {:each, nth, 0, inner}
    end

    @doc "Condition which checks inner condition if there're already more than `num` products"
    @spec over?(t(), pos_integer()) :: t()
    def over?(inner \\ any?(), num) when is_integer(num) and num > 0 do
      {:over, num, 0, inner}
    end

    @doc "Evaluate condition on a product, possibly updating condition state"
    @spec check(t(), Product.t()) :: {boolean(), t()}
    def check(:any = condition, _product) do
      {true, condition}
    end

    def check({:product, code, inner}, product = %Product{code: code}) do
      {applies?, inner} = check(inner, product)
      {applies?, {:product, code, inner}}
    end

    def check({:product, _, _} = condition, _product) do
      {false, condition}
    end

    def check({:each, nth, counter, inner}, product) when counter + 1 == nth do
      {applies?, inner} = check(inner, product)
      {applies?, {:each, nth, 0, inner}}
    end

    def check({:each, nth, counter, inner}, _product) do
      {false, {:each, nth, counter + 1, inner}}
    end

    def check({:over, num, counter, inner}, product) when counter >= num do
      {applies?, inner} = check(inner, product)
      {applies?, {:over, num, counter + 1, inner}}
    end

    def check({:over, num, counter, inner}, _product) do
      {false, {:over, num, counter + 1, inner}}
    end

  end

  @doc """
  Construct a named rule given a discount definition.
  * Narrow down when this rule is _evaluated_ with a `:precondition` option. By default
    `Checkout.Rule.Condition.any?` is implied here.
  * Restrict when any discounts produced by this rule become "active" with `:postcondition` option.
    By default `Checkout.Rule.Condition.any?` is implied here as well.
  """
  @spec new(String.t(), discount(), keyword()) :: t()
  def new(name, definition, opts \\ []) do
    %Rule{
      name: name,
      definition: definition,
      precondition: opts[:precondition] || Condition.any?,
      postcondition: opts[:postcondition] || Condition.any?
    }
  end

  defmodule Discount do
    @moduledoc """
    A discount rule.
    This rule produces an item in a final cart which has a name and negative price.
    """

    use TypedStruct

    import Ratio, only: [<|>: 2]

    @type amount() ::
      Checkout.amount() |
      Ratio.t()

    typedstruct do
      field :amount, amount(), default: 0
    end

    alias __MODULE__

    @doc "Express discount in absolute currency units"
    @spec absolute(Checkout.amount()) :: t()
    def absolute(amount) when is_integer(amount) do
      %Discount{amount: amount}
    end

    @doc "Express discount as share of product or total price"
    @spec share(integer(), pos_integer()) :: t()
    def share(parts, of) when is_integer(parts) and is_integer(of) do
      %Discount{amount: parts <|> of}
    end

    @doc "Express discount as number of percents of product or total price"
    @spec percents(integer()) :: t()
    def percents(percents) do
      share(percents, 100)
    end

    @doc "Compute discounted amount in absolute currency units"
    @spec compute(t(), Checkout.amount()) :: Checkout.amount()
    def compute(%Discount{amount: amount}, _price) when is_integer(amount) do
      amount
    end

    def compute(%Discount{amount: amount}, price) when Ratio.is_rational(amount) do
      Ratio.mult(price <|> 1, amount) |> Ratio.trunc()
    end

  end

  @doc """
  Indicate that this discount is bulk discount rule
  Bulk discount always produces a single discount item for any number of products applied to it.
  """
  @spec bulk(Discount.t()) :: bulk_discount()
  def bulk(discount) do
    {:bulk, 0, discount}
  end

  @doc "Evaluate rule given next product added to a cart and update rule's state"
  @spec apply(t(), Product.t()) :: t()
  def apply(%Rule{} = rule, product) do
    {applies?, rule} = check_precondition(rule, product)
    if applies? do
      rule |> update(product) |> check_postcondition(product)
    else
      rule
    end
  end

  defp check_precondition(%Rule{} = rule, product) do
    precondition = rule.precondition || Condition.any?()
    {applies?, precondition} = Condition.check(precondition, product)
    {applies?, %Rule{rule | precondition: precondition}}
  end

  defp check_postcondition(%Rule{} = rule, product) do
    postcondition = rule.postcondition || Condition.any?()
    {applies?, postcondition} = Condition.check(postcondition, product)
    %Rule{rule | active?: applies?, postcondition: postcondition}
  end

  defp update(%Rule{definition: %Discount{} = discount} = rule, product) do
    item = produce_item(rule, discount, product.price)
    %Rule{rule | items: [item | rule.items]}
  end

  defp update(%Rule{definition: {:bulk, total, discount}} = rule, product) do
    total = total + product.price
    item = produce_item(rule, discount, total)
    %Rule{rule | items: [item], definition: {:bulk, total, discount}}
  end

  defp produce_item(%Rule{name: name}, discount, price) do
    %Checkout.Discount{name: name, amount: Discount.compute(discount, price)}
  end

  @doc "Emit a list of items suitable to be shown among other cart items"
  @spec items(t()) :: [Checkout.Cart.item()]
  def items(%Rule{} = rule) do
    if rule.active?, do: rule.items, else: []
  end

  @doc "Compute effective price offset introduced by this rule so far"
  @spec total(t()) :: Checkout.amount()
  def total(%Rule{} = rule) do
    rule
      |> items()
      |> Enum.map(&Map.get(&1, :amount))
      |> Enum.sum()
  end

end
