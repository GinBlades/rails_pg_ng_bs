## 1 - Setup Devise and Bootstrap

Create the new application without turbolinks, spring, or test unit

    rails new shine --skip-turbolinks --skip-spring --skip-test-unit -d postgresql

Set up the database

    bundle exec rake db:create:all

Create a root path

    # config/routes.rb
    root "dashboard#index"

    # controllers/dashboard_controller.rb
    def index
    end

    # views/dashboard/index.html.erb
    Welcome to Shine!

Install devise

    # Gemfile
    gem "devise" # Rails 5 use: gem 'devise', '>= 4.0.0.rc1'

    bundle exec rails g devise:install
    bundle exec rails g devise user

    # controllers/application_controller
    before_action :authenticate_user!

    # views/dashboard/index
    Welcome <%= current_user.email %>

    bundle exec rake db:migrate

You can see the record in the database

    bundle exec rails dbconsole
    \x on # expaneded display
    select * from user;

Setup bower

    npm install -g bower

    # Gemfile
    gem "bower-rails"

    bundle install

This gives you rake tasks, which you can see in `bundle exec rake -T bower`. Create a Bowerfile:

    # Bowerfile
    asset "bootstrap-sass-official"

    bundle exec rake bower:install

This will download the files to `vendor/assets/bower_components`. In your stylesheet you can add
a reference to this

    
    # app/assets/stylesheets/application.css
    *= require "bootstrap-sass-official"

With the `bower-rails` gem, you'll be able to use the `bower.json` file to get the route to the right
source.

Install the devise views

    bundle exec rails g devise:views

Style them for bootstrap

Update devise initializer for password length and restrict email to `example.com` email

    # config/initializers/devise.rb
    config.password_length = 10..128
    config.email_regexp = /|A[^@]+@example\.com|z/

## Chapter 2 - Secure Login Database with Postgres Constraints

We will add a mail constraint directly to the database

    b-rails g migration add-email-constraint-to-users
    
    # migration
    def up
        execute %(
        ALTER TABLE
            users
        ADD CONSTRAINT
            email_must_be_company_email
        CHECK ( email ~* '^[^@]+@example||.com' )
        )
    end

    def down
        execute %(
        ALTER TABLE
            users
        DROP CONSTRAINT
            email_must_be_company_email
        )
    end

Because we're using this constraint, the rails schema wont pick it up. Convert the schema to sql

    # config/application.rb
    config.active_record.schema_format = :sql

## Chapter 3 - Fast Queries with Advanced Postgres Indexes

Create a new table for customers

    b-rails g model customer first_name last_name email username

Set all fields to `null: false` and index email and username

    create_table :customers do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :username, null: false

      t.timestamps
      t.index :email, unique: true
      t.index :username, unique: true
    end

Use faker to set up dummy data

    # Gemfile
    gem "faker"

    bundle

    # db/seeds.rb
    100_000.times do |i|
    Customer.create!(
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        username: "#{Faker::Internet.user_name}#{i}",
        email: Faker::Internet.user_name + i.to_s + "@#{Faker::Internet.domain_name}"
    )
    end

Create a route to display customers

    resources :customers, only: [:index]

    # controllers/customers_controller.rb
    def index
        @customers = Customer.all.limit(10)
    end

    # views/customers/index.html
    <header>
        <h1 class="h2">Customer Search</h1>
    </header>
    <section class="search-form">
        <%= form_for :customers, method: :get do |f| %>
            <div class="input-group input-group-lg">
                <%= label_tag :keywords, nil, class: "sr-only" %>
                <%= text_field_tag :keywords, nil, placeholder: "First, Last, or Email", class: "form-control input-lg" %>
                <span class="input-group-btn">
                    <%= submit_tag "Find Customers", class: "btn btn-primary btn-lg" %>
                </span>
            </div>
        <% end %>
    </section>
    <section class="search-results">
    <header>
        <h1 class="h3">Results</h1>
    </header>
    <table class="table table-striped">
        <thead>
        <tr>
            <th>First Name</th>
            <th>Last NAme</th>
            <th>Email</th>
            <th>Joined</th>
        </tr>
        </thead>
        <tbody>
        <% @customers.each do |customer| %>
            <tr>
            <td><%= customer.first_name %></td>
            <td><%= customer.last_name %></td>
            <td><%= customer.email %></td>
            <td><%= l customer.created_at.to_date %></td>
            </tr>
        <% end %>
        </tbody>
    </table>
    </section>

The search logic is fairly complex:

* If the search term contains a `@`, search email
* Use `name` part of email if email is given, (bob from bob123@example.com)
* If the search term does not contain `@`, search only first and last name
* Search is case-insensitive
* Search should match start of the word, (Bob should match Bobby)
* Order by exact email first and others by last name

The initial sequel might be like this:

    SELECT *
    FROM customers
    WHERE lower(first_name) LIKE 'bob%'
    OR lower(last_name) LIKE 'bob%'
    OR lower(email) = 'bob@example.com'
    ORDER BY email = 'bob@example.com' DESC, last_name ASC

For use with active record the syntax is:

    Customer.where("lower(first_name) LIKE :first_name OR " +
                    "lower(last_name) LIKE :last_name OR " +
                    "lower(email) = :email", {
                        first_name: "bob%",
                        last_name: "bob%",
                        email: "bob@example.com"
                    }).order("email = 'bob@example.com' desc, last_name asc")

If there is no `@` symbol, we can skip the email portion of the search. Create a class to decide
which search to use

    # app/models/customer_search_term.rb
    class CustomerSearchTerm
        attr_reader :where_clause, :where_args, :order
        def initialize(search_term)
            search_term = search_term.downcase
            @where_clause = ""
            @where_args = {}
            if search_term =~ /@/
                build_for_email_search(search_term)
            else
                build_for_name_search(search_term)
            end
        end

        def build_for_name_search(search_term)
            @where_clause << case_insensitive_search(:first_name)
            @where_args[:first_name] = starts_with(search_term)

            @where_clause << " OR #{case_insensitive_search(:last_name)}"
            @where_args[:last_name] = starts_with(search_term)

            @order = "last_name asc"
        end
        
        def starts_with(search_term)
            search_term + "%"
        end

        def case_insensitive_search(field_name)
            "lower(#{field_name}) like :#{field_name}"
        end

        def extract_name(email)
            email.gsub(/@.*$/, "").gsub(/[0-9]+/, "")
        end

        def build_for_email_search(search_term)
            @where_clause << case_insensitive_search(:first_name)
            @where_args[:first_name] = starts_with(search_term)

            @where_clause << " OR #{case_insensitive_search(:last_name)}"
            @where_args[:last_name] = starts_with(search_term)

            @where_clause << " OR #{case_insensitive_search(:email)}"
            @where_args[:email] = search_term

            # Don't put user accessible term directly in SQL
            @order = "lower(email) =" +
                ActiveRecord::Base.connection.quote(search_term) +
                " desc, last_name asc"
        end
    end

    # controllers/customers_controller.rb
    def index
        if params[:keywords].present?
        @keywords = params[:keywords]
        customer_search_term = CustomerSearchTerm.new(@keywords)
        @customers = Customer.where(
            customer_search_term.where_clause,
            customer_search_term.where_args).order(customer_search_term.order)
        else
        @customers = []
        end
    end

You can uses `EXPLAIN ANALYZE` in PostgreSQL to show details about a query

    EXPLAIN ANALYZE
        SELECT *
        FROM customers
        WHERE lower(first_name) LIKE 'bob%'
        OR lower(last_name) LIKE 'bob%'
        OR lower(email) = 'bob@example.com'
        ORDER BY email = 'bob@example.com' DESC, last_name ASC

This output will give you the sorting results>

Line | Explaination
--- | ---
Sort (...) Sort Key: (...) Sort Method: | This shows you how the `order by` clause worked
Seq Scan on customers (...) | This explains that Postgres had to example every row, in this case.
Filter: (...) | Interpretation of the `where` clause
Total Runtime | Estimated runtime of the query.

Postgres allows you to create an index of transformed values to optimize for lowercase searches or partial text searches. Implement
these indexes on a migration.

    b-rails g migration add-lower-indexes-to-customers

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
        remove_index :customers, name: "customers_lower_last_name"
        remove_index :customers, name: "customers_lower_first_name"
        remove_index :customers, name: "customers_lower_email"
    end

The `varchar_pattern_ops` term is an **operator class**, which will allow Postgres to optimize for `like` searches. Run the `EXPLAIN ANALYZE` command in the dbconsole to see the difference. The `SeqScan` is gone and there are **index scans** that are able to skip some rows in the database.

## Chapter 4 - Styling Search Results

Convert the table:

  <ol class="list-group">
    <% @customers.each do |customer| %>
      <li class="list-group-item clearfix">
        <h3 class="pull-right">
          Joined <%= l customer.created_at.to_date %>
        </h3>
        <h2 class="h3">
          <%= customer.first_name %> <% customer.last_name %>
          <small><%= customer.username %></small>
        </h2>
        <h4><%= customer.email %></h4>
      </li>
    <% end %>
  </ol>

Add paging to the controller and view:

    PAGE_SIZE = 10
    def index
        @page = (params[:page] || 0).to_i
        ...
            .offset(PAGE_SIZE * @page).limit(PAGE_SIZE)


    # _pager.html
    <nav>
    <ul class="pager">
    <li class="previous <%= page == 0 ? 'disabled' : '' %>">
        <%= link_to_if page > 0, "&larr; Previous".html_safe,
            customers_path(keywors: keywords, page: page - 1) %>
    </li>
    <li class="next">
        <%= link_to "Next &rarr;".html_safe,
            customers_path(keywords: keywords, page: page + 1) %>
    </li>
    </ul>
    </nav>

    # index.html
    ...
    <%= render "pager", { keywords: @keywords, page: @page } %>
