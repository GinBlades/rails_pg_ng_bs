require "rails_helper"

feature "Customer Search" do
  let(:email) { "bob@example.com" }
  let(:password) { "password123" }

  def create_customer(first_name: nil, last_name: nil, email: nil)
    first_name ||= Faker::Name.first_name
    last_name ||= Faker::Name.last_name
    email ||= "#{Faker::Internet.user_name}#{rand(1000)}@" + "#{Faker::Internet.domain_name}"
    Customer.create!(first_name: first_name, last_name: last_name,
                     username: "#{Faker::Internet.user_name}#{rand(1000)}", email: email)
  end

  before do
    User.create!(email: email,
                 password: password,
                 password_confirmation: password)

    %w(Robert Bob JR Bobby Dobbs).zip(%w(Aaron Johnson Bob Dobbs Jones)).each do |name|
      if name[1] == "Jones"
        create_customer first_name: name[0], last_name: name[1], email: "bob123@somewhere.net"
      else
        create_customer first_name: name[0], last_name: name[1]
      end
    end

    visit "/customers"
    fill_in "Email", with: "bob@example.com"
    fill_in "Password", with: "password123"
    click_button "Log in"
  end

  scenario "Search by Name" do
    within "section.search-form" do
      fill_in "keywords", with: "bob"
    end

    within "section.search-results" do
      expect(page).to have_content("Results")
      expect(page.all("ol li.list-group-item").count).to eq(4)
      expect(page.all("ol li.list-group-item")[0]).to have_content("JR")
      expect(page.all("ol li.list-group-item")[0]).to have_content("Bob")
      expect(page.all("ol li.list-group-item")[3]).to have_content("Bob")
      expect(page.all("ol li.list-group-item")[3]).to have_content("Jones")
    end
  end
end
