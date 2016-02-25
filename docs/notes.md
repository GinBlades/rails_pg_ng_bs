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
