require_relative 'test_helper'
require_relative '../lib/item_repository'

class ItemRepositoryTest < Minitest::Test
  def setup
    @ir = ItemRepository.new
  end

  def test_it_exists
    @ir = ItemRepository.new
    assert_instance_of ItemRepository, @ir
  end

  def test_it_can_create_items_from_csv
    @ir.from_csv("./data/items.csv")
    # ("./test/fixtures/item_fixtures.csv")
    assert_equal 1368, @ir.elements.count
    assert_instance_of Item, @ir.elements[263395237]
    assert_instance_of Item, @ir.elements[263414049]
    assert_equal "Snow fallen", @ir.elements[263414049].name
    assert_equal "Minty Green Knit Crochet Infinity Scarf", @ir.elements[263567474].name
    # i = @ir.elements
    # binding.pry
    # assert_instance_of Item, @ir.elements[-1]
  end


end