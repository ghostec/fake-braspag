require 'redis'
require 'json'

# Public: Class responsible to make operations upon an order.
class Order
  # Public: Raised when there is no order with the provided id on the
  # persistence layer.
  class NotFoundError < StandardError; end

  # Internal: The redis key prefix used to store the orders.
  KEY_PREFIX = 'fake-braspag.order.'

  @@connection = Redis.new

  # Public: Returns the connection object.
  #
  # This object can be used to make raw operation on the persistence layer.
  def self.connection
    @@connection
  end

  # Public: Finds and return an order with the provided `id`.
  #
  # Examples
  #
  #   Order.find('12345')
  #   # => #<Order:... @attributes={"orderId"=>"12345", "amount"=>"18.36"}, @persisted=true>
  #
  #   Order.find('non existend')
  #   # => Order::NotFoundError
  #
  # Raises `Order::NotFoundError` if no order is found with the id on the
  # persistence layer.
  def self.find(id)
    Order.new(get_value_for(key_for(id)), persisted: true)
  end

  # Public: Same as `.find` but returns `nil` if no order is found with the id
  # on the persistence layer.
  def self.find!(id)
    Order.new(get_value_for(key_for(id)), persisted: true)
  rescue NotFoundError
    nil
  end

  # Public: Create an order with the provided `parameters`.
  #
  # Examples
  #
  #   Order.create('orderId' => '12345', 'amount' => '18.36')
  #   # => #<Order:... @attributes={"orderId"=>"12345", "amount"=>"18.36"}, @persisted=true>
  #
  # Returns a `Order` object or false if already exist an order with the same id.
  def self.create(parameters)
    order = new(parameters)
    return_value = order.save

    order if return_value
  end

  # Public: Returns the number of orders on the persistence layer.
  def self.count
    connection.keys(KEY_PREFIX + '*').size
  end

  # Internal: Returns the full key to be used on the persistence layer.
  def self.key_for(id)
    KEY_PREFIX + id.to_s
  end

  # Internal: Get the value of the order attributes from the persistence layer.
  #
  # Returns a `Hash` with the attributes.
  # Raises `Order::NotFoundError` if the key is not persisted.
  def self.get_value_for(key)
    value = connection.get(key)

    if value
      JSON.load(value)
    else
      raise NotFoundError
    end
  end

  # Public: Initialize a Order.
  #
  # attributes - a Hash with the order attributes.
  def initialize(attributes, persisted: false)
    attributes['amount'] = normalize_amount(attributes['amount'])
    attributes['cardNumber'] = mask_card_number(attributes['cardNumber'])

    @attributes = attributes
    @persisted = persisted
  end

  # Public: Saves the object on the persistence layer.
  #
  # Returns true if the object could be salved, false otherwise.
  def save
    options = @persisted ? { xx: true } : { nx: true }

    success = connection.set(self.class.key_for(self['orderId']), to_json, options)

    @persisted = true if success

    success
  end

  # Public: Reload the attributes information for the persistence layer.
  #
  # Raises `Order::NotFoundError` if no order is found with the id on the
  # persistence layer.
  def reload
    @attributes = self.class.get_value_for(self.class.key_for(self['orderId']))
    @persisted = true
  end

  # Public: Marks the order as captured.
  def capture!
    @attributes['status'] = 'captured'
    save
  end

  # Public: Checks if the order is captured.
  def captured?
    @attributes['status'] == 'captured'
  end

  # Public: Get the attribute from the order.
  #
  # Example:
  #
  #     order['orderId'] # => '2223'
  def [](attribute)
    @attributes[attribute]
  end

  # Internal: Serializes the attributes to JSON.
  def to_json
    @attributes.to_json
  end

  def connection
    self.class.connection
  end

  private

  # Internal: Normalize the amount value to always use `'.'` as decimal
  # separator.
  def normalize_amount(amount)
    amount.gsub(',', '.') if amount
  end

  # Internal: Add a mask to `card_number` to only show the last 4 digits.
  def mask_card_number(card_number)
    "************%s" % card_number[-4..-1] if card_number
  end
end
