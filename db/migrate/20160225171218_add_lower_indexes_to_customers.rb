class AddLowerIndexesToCustomers < ActiveRecord::Migration[5.0]
  def up
    execute %(
      CREATE INDEX
        customers_lower_last_name
      ON
        customers (lower(last_name) varchar_pattern_ops)
    )
    execute %(
      CREATE INDEX
        customers_lower_first_name
      ON
        customers (lower(first_name) varchar_pattern_ops)
    )
    execute %(
      CREATE INDEX
        customers_lower_email
      ON
        customers (lower(email) varchar_pattern_ops)
    )
  end

  def down
    execute %(
        DROP INDEX customers_lower_last_name;
        DROP INDEX customers_lower_first_name;
        DROP INDEX customers_lower_email;
    )
  end
end
