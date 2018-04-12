require_relative 'test_helper'
require_relative '../lib/invoice'
require_relative '../lib/sales_engine'

# Test Invoice class
class InvoiceTest < Minitest::Test

  def setup
    @time = Time.now
    @inv = Invoice.new(
                      id:          3,
                      customer_id: 7,
                      merchant_id: 8,
                      status:      'pending',
                      created_at:  @time,
                      updated_at:  @time
                      )
  end

  def test_it_exists
    assert_instance_of Invoice, @inv
  end

  def test_it_has_attributes
    assert_equal 3, @inv.id
    assert_equal 7, @inv.customer_id
    assert_equal 8, @inv.merchant_id
    assert_equal :pending, @inv.status
    assert_equal @time, @inv.created_at
    assert_equal @time, @inv.updated_at
  end

  def test_it_returns_merchant
    se = SalesEngine.from_csv(
                              items:      './data/items.csv',
                              merchants:  './test/fixtures/merchants_fixtures.csv',
                              invoices:   './test/fixtures/invoices_fixtures.csv'
                              )
    invoice = se.invoices.find_by_id(18)
    assert_instance_of Merchant, invoice.merchant
    assert_equal 12334839, invoice.merchant.id
  end

  def test_it_can_check_if_invoice_paid_in_full
    se = SalesEngine.from_csv(
                              items:      './data/items.csv',
                              merchants:  './test/fixtures/merchants_fixtures.csv',
                              transactions:  './test/fixtures/transactions_fixtures.csv',
                              invoices:   './test/fixtures/invoices_fixtures.csv'
                              )
    invoice = se.invoices.find_by_id(46)
    assert invoice.is_paid_in_full?
    invoice = se.invoices.find_by_id(40)
    refute invoice.is_paid_in_full?
  end

  def test_it_can_return_invoice_total
    se = SalesEngine.from_csv(
                              items:      './data/items.csv',
                              merchants:  './test/fixtures/merchants_fixtures.csv',
                              invoice_items:  './test/fixtures/invoice_items_fixtures.csv',
                              invoices:   './test/fixtures/invoices_fixtures.csv'
                              )
    invoice = se.invoices.find_by_id(1)
    assert_equal 21067.77, invoice.total
  end
end
