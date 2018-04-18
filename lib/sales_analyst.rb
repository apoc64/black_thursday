require 'bigdecimal'
# Class that analyzes sales data
class SalesAnalyst
  attr_reader :engine

  def initialize(sales_engine)
    @engine = sales_engine
  end

  def average_items_per_merchant
    items = @engine.items.elements.count.to_f
    merchants = @engine.merchants.elements.count.to_f
    (items / merchants).round(2)
  end

  def average_items_per_merchant_standard_deviation
    merchants = @engine.merchants.all.map do |merchant|
      @engine.items.find_all_by_merchant_id(merchant.id).count
    end
    average = average_items_per_merchant
    standard_deviation(merchants, average)
  end

  def merchants_with_high_item_count
    threshold = average_items_per_merchant +
                (average_items_per_merchant_standard_deviation * 1)
    @engine.merchants.all.find_all do |merchant|
      merch_count = @engine.items.find_all_by_merchant_id(merchant.id).count
      merch_count > threshold
    end
  end

  def average_item_price_for_merchant(merchant_id)
    items = @engine.items.find_all_by_merchant_id(merchant_id)
    total_cost = items.reduce(0.0) do |total, item|
      total + item.unit_price
    end
    (total_cost / items.count).round(2)
  end

  def average_average_price_per_merchant
    merchants = @engine.merchants.all
    total_cost = merchants.reduce(0.0) do |total, merchant|
      total + average_item_price_for_merchant(merchant.id)
    end
    (total_cost / merchants.count).round(2)
  end

  def average_item_cost
    items = @engine.items.all
    total_cost = items.reduce(0.0) do |total, item|
      total + item.unit_price
    end
    (total_cost / items.count).round(2)
  end

  def golden_items
    threshold = average_item_cost +
                (item_unit_price_standard_deviation * 2)
    @engine.items.all.find_all do |item|
      item.unit_price > threshold
    end
  end

  def item_unit_price_standard_deviation
    items = @engine.items.all.map(&:unit_price)
    average = average_item_cost
    standard_deviation(items, average)
  end

  def standard_deviation(elements, average)
    deviation_sum = elements.reduce(0) do |sum, element|
      sum + (element.to_f - average).abs**2
    end
    divided_deviation = deviation_sum / (elements.count - 1)
    Math.sqrt(divided_deviation).round(2).to_f
  end

  def average_invoices_per_merchant
    invoices = @engine.invoices.elements.count.to_f
    merchants = @engine.merchants.elements.count.to_f
    (invoices / merchants).round(2)
  end

  def average_invoices_per_merchant_standard_deviation
    merchants = @engine.merchants.all.map do |merchant|
      @engine.invoices.find_all_by_merchant_id(merchant.id).count
    end
    average = average_invoices_per_merchant
    standard_deviation(merchants, average)
  end

  def top_merchants_by_invoice_count
    threshold = average_invoices_per_merchant +
                (average_invoices_per_merchant_standard_deviation * 2)
    @engine.merchants.all.find_all do |merchant|
      merch_count = @engine.invoices.find_all_by_merchant_id(merchant.id).count
      merch_count > threshold
    end
  end

  def bottom_merchants_by_invoice_count
    threshold = average_invoices_per_merchant -
                (average_invoices_per_merchant_standard_deviation * 2)
    @engine.merchants.all.find_all do |merchant|
      merch_count = @engine.invoices.find_all_by_merchant_id(merchant.id).count
      merch_count < threshold
    end
  end

  def top_days_by_invoice_count
    days = generate_day
    average = average_days(days)
    stnd_dev = standard_deviation(days.values, average)
    threshold = average + (stnd_dev * 1)
    top_day_numbers = top_days(days, threshold)
    top_day_numbers.map do |day|
      Date::DAYNAMES[day]
    end
  end

  def top_days(days, threshold)
    top_days = days.find_all do |day|
      day[1] > threshold
    end
    top_days.map do |day|
      day[0]
    end
  end

  def average_days(days)
    days.values.reduce(0) do |sum, num|
      sum + num
    end / 7
  end

  def generate_day
    days = @engine.invoices.all.group_by do |invoice|
      invoice.created_at.wday
    end
    days.map do |day, invoices|
      [day, invoices.count]
    end.to_h
  end

  def invoice_by_day_standard_deviation
    days = generate_day
    average = average_days(days)
    standard_deviation(days.values, average)
  end

  def invoice_status(status)
    statuses = @engine.invoices.all.group_by(&:status)
    mapped_statuses = statuses.map do |new_status, invoices|
      [new_status, invoices.count]
    end.to_h
    final = mapped_statuses[status].to_f / @engine.invoices.all.count.to_f
    (final * 100).round(2)
  end

  def invoice_paid_in_full?(invoice_id)
    transactions = @engine.transactions.find_all_by_invoice_id(invoice_id)
    transactions.any? do |transaction|
      transaction.result == :success
    end
  end

  def invoice_total(invoice_id)
    invoice_items = @engine.invoice_items.find_all_by_invoice_id(invoice_id)
    invoice_items.reduce(0) do |total, invoice_item|
      total + invoice_item.unit_price * invoice_item.quantity
    end
  end

  def total_revenue_by_date(date)
    invoices = @engine.invoices.all.find_all do |invoice|
      invoice.created_at == date
    end
    invoices.reduce(0) do |total, invoice|
      total + invoice_total(invoice.id)
    end
  end

  def top_revenue_earners(num = 20)
    merchants_ranked_by_revenue[0..num - 1]
  end

  def merchants_ranked_by_revenue
    tops = @engine.merchants.all.sort_by do |merchant|
      invoices = @engine.invoices.find_all_by_merchant_id(merchant.id)
      invoices.reduce(0, &method(:revenue_for_invoice))
    end.reverse
    tops
  end

  def revenue_for_invoice(total, invoice)
    return total unless invoice_paid_in_full?(invoice.id)
    total + invoice_total(invoice.id)
  end

  def merchants_with_pending_invoices
    @engine.merchants.all.find_all do |merchant|
      merchant_has_pending_invoice?(merchant)
    end
  end

  def merchant_has_pending_invoice?(merchant)
    invoices = @engine.invoices.find_all_by_merchant_id(merchant.id)
    invoices.any? do |invoice|
      invoice_is_pending?(invoice)
    end
  end

  def invoice_is_pending?(invoice)
    transactions = @engine.transactions.find_all_by_invoice_id(invoice.id)
    transactions.all? do |transaction|
      transaction.result != :success
    end
  end

  def merchants_with_only_one_item
    @engine.merchants.all.find_all do |merchant|
      @engine.items.find_all_by_merchant_id(merchant.id).count == 1
    end
  end

  def merchants_with_only_one_item_registered_in_month(month)
    merchants_by_month = merchants_with_only_one_item.group_by do |merchant|
      merchant.created_at.strftime('%B')
    end
    merchants_by_month[month]
  end

  def revenue_by_merchant(merchant)
    BigDecimal.new(1)
    # @engine.merchants.find_all_by_merchant_id(merchant.id)
  end

  def most_sold_item_for_merchant(merchant_id)
    invoice_items = invoice_items_from_merchant(merchant_id)
    quantities = invoice_items.group_by(&:quantity)
    find_maximum_value(quantities)
  end

  def best_item_for_merchant(merchant_id)
    invoice_items = invoice_items_from_merchant(merchant_id)
    revenue = invoice_items.group_by do |invoice_item|
      invoice_item.quantity * invoice_item.unit_price
    end
    find_maximum_value(revenue)[0]
  end

  def invoice_items_from_merchant(merchant_id)
    invoices = @engine.invoices.find_all_by_merchant_id(merchant_id)
    invoices.map do |invoice|
      unless invoice_is_pending?(invoice)
        @engine.invoice_items.find_all_by_invoice_id(invoice.id)
      end
    end.flatten.compact
  end

  def find_maximum_value(amounts)
    max = amounts.keys.max
    amounts[max].map do |invoice_item|
      @engine.items.find_by_id(invoice_item.item_id)
    end
  end

  def top_buyers(num = 20)
    customers_ranked_by_revenue[0..num - 1]
  end

  def customers_ranked_by_revenue
    tops = @engine.customers.all.sort_by do |customer|
      invoices = @engine.invoices.find_all_by_customer_id(customer.id)
      invoices.reduce(0, &method(:revenue_for_invoice))
    end.reverse
    tops
  end

  def top_merchant_for_customer(customer_id)
    invoices = @engine.invoices.find_all_by_customer_id(customer_id)
    grouped_invoices = invoices.group_by(&:merchant_id)
    quantities = quantities_for_grouped_invoices(grouped_invoices)
    max = quantities.keys.max
    @engine.merchants.find_by_id(quantities[max])
  end

  def quantities_for_grouped_invoices(grouped_invoices)
    grouped_invoices.map do |merch_id, invoices|
      total_quantity = total_quantity_for_invoices(invoices)
      [total_quantity, merch_id]
    end.to_h
  end

  def total_quantity_for_invoices(invoices)
    invoices.reduce(0) do |sum, invoice|
      invoice_items = @engine.invoice_items.find_all_by_invoice_id(invoice.id)
      sum + invoice_items.reduce(0) do |total, invoice_item|
        total + invoice_item.quantity
      end
    end
  end

  def one_time_buyers
    @engine.customers.all.find_all do |customer|
      @engine.invoices.find_all_by_customer_id(customer.id).count == 1
    end
  end

  def one_time_buyers_top_item
    invoices = get_invoices_for_customers(one_time_buyers)
    invoice_items = get_invoice_items_from_invoices(invoices)
    item_ids_with_quantity = get_item_ids_with_quantity(invoice_items)
    items_hash = item_ids_with_total_quantity(item_ids_with_quantity)
    item_id = items_hash.key(items_hash.values.max)
    @engine.items.find_by_id(item_id)
  end

  def get_invoices_for_customers(customers)
    customers.map do |customer|
      @engine.invoices.find_all_by_customer_id(customer.id)
    end.flatten
  end

  def get_invoice_items_from_invoices(invoices)
    invoices.map do |invoice|
      if invoice_paid_in_full?(invoice.id)
        @engine.invoice_items.find_all_by_invoice_id(invoice.id)
      end
    end.flatten.compact
  end

  def get_item_ids_with_quantity(invoice_items)
    invoice_items.map do |invoice_item|
      [invoice_item.item_id, invoice_item.quantity]
    end
  end

  def item_ids_with_total_quantity(item_ids_with_quantity)
    items_hash = Hash.new(0)
    item_ids_with_quantity.each do |item_with_quantity|
      items_hash[item_with_quantity[0]] += item_with_quantity[1]
    end
    items_hash
  end

  def items_bought_in_year(customer_id, year)
    invoices = @engine.invoices.find_all_by_customer_id(customer_id)
    invoices_for_year = invoices.find_all do |invoice|
      invoice.created_at.year == year
    end
    invoice_items = get_invoice_items_from_invoices(invoices_for_year)
    invoice_items.map do |invoice_item|
      @engine.items.find_by_id(invoice_item.item_id)
    end
  end

  def highest_volume_items(customer_id)
    invoices = @engine.invoices.find_all_by_customer_id(customer_id)
    invoice_items = invoices.map do |invoice|
      @engine.invoice_items.find_all_by_invoice_id(invoice.id)
    end.flatten.compact
    quantities = get_item_ids_with_quantity(invoice_items)
    item_ids_by_quantity = item_ids_with_total_quantity(quantities).to_a
    max = item_ids_by_quantity.max_by do |item_id_with_quantity|
      item_id_with_quantity[1]
    end[1]
    max_item_ids_with_quantity = item_ids_by_quantity.find_all do |iidwq|
      iidwq[1] == max
    end
    max_item_ids_with_quantity.map do |item_id_with_quantity|
      @engine.items.find_by_id(item_id_with_quantity[0])
    end
  end
end
