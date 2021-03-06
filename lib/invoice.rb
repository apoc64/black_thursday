require_relative 'element'

# This class defines invoices
class Invoice
  include Element

  def initialize(attributes)
    @attributes = attributes
  end

  def customer_id
    @attributes[:customer_id].to_i
  end

  def status
    @attributes[:status].to_sym
  end

  def update(states)
    super(states)
    attributes[:status] = states[:status] if states[:status]
  end
end
