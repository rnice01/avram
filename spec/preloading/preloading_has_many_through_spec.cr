require "../spec_helper"

include LazyLoadHelpers

class Comment::BaseQuery
  include QuerySpy
end

describe "Preloading has_many through associations" do
  context "through is a has_many association that has a belongs_to relationship to target" do
    it "works" do
      with_lazy_load(enabled: false) do
        tag = TagBox.create
        TagBox.create # unused tag
        post = PostBox.create
        other_post = PostBox.create
        TaggingBox.create &.tag_id(tag.id).post_id(post.id)
        TaggingBox.create &.tag_id(tag.id).post_id(other_post.id)

        post_tags = Post::BaseQuery.new.preload_tags.results.first.tags

        post_tags.size.should eq(1)
        post_tags.should eq([tag])
      end
    end

    it "works with uuid foreign keys" do
      with_lazy_load(enabled: false) do
        item = LineItemBox.create
        other_item = LineItemBox.create
        product = ProductBox.create
        ProductBox.create # unused product
        LineItemProductBox.create &.line_item_id(item.id).product_id(product.id)
        LineItemProductBox.create &.line_item_id(other_item.id).product_id(product.id)

        item_products = LineItemQuery.new.preload_associated_products.results.first.associated_products

        item_products.size.should eq(1)
        item_products.should eq([product])
      end
    end

    it "does not fail when getting results multiple times" do
      PostBox.create

      posts = Post::BaseQuery.new.preload_tags

      2.times { posts.results }
    end
  end

  context "through is a has_many association that has a has_many relationship to target" do
    it "works" do
      with_lazy_load(enabled: false) do
        manager = ManagerBox.create
        employee = EmployeeBox.new.manager_id(manager.id).create
        customer = CustomerBox.new.employee_id(employee.id).create

        customers = Manager::BaseQuery.new.preload_customers.find(manager.id).customers

        customers.size.should eq(1)
        customers.should eq([customer])
      end
    end
  end

  context "through is a belongs_to association that has a belongs_to relationship to target" do
    it "works" do
      with_lazy_load(enabled: false) do
        manager = ManagerBox.create
        employee = EmployeeBox.new.manager_id(manager.id).create
        customer = CustomerBox.new.employee_id(employee.id).create

        managers = Customer::BaseQuery.new.preload_managers.find(customer.id).managers

        managers.size.should eq(1)
        managers.should eq([manager])
      end
    end
  end

  context "with existing record" do
    it "works" do
      with_lazy_load(enabled: false) do
        tag = TagBox.create
        post = PostBox.create
        TaggingBox.create &.tag_id(tag.id).post_id(post.id)

        post = Post::BaseQuery.preload_tags(post)

        post.tags.should eq([tag])
      end
    end

    it "works with multiple" do
      with_lazy_load(enabled: false) do
        tag1 = TagBox.create
        tag2 = TagBox.create
        post1 = PostBox.create
        post2 = PostBox.create
        TaggingBox.create &.tag_id(tag1.id).post_id(post1.id)
        TaggingBox.create &.tag_id(tag2.id).post_id(post2.id)

        posts = Post::BaseQuery.preload_tags([post1, post2])

        posts[0].tags.should eq([tag1])
        posts[1].tags.should eq([tag2])
      end
    end

    it "works with custom query" do
      with_lazy_load(enabled: false) do
        manager = ManagerBox.create
        employee1 = EmployeeBox.new.manager_id(manager.id).create
        employee2 = EmployeeBox.new.manager_id(manager.id).create
        customer1 = CustomerBox.new.employee_id(employee1.id).create
        CustomerBox.new.employee_id(employee2.id).create
        customer3 = CustomerBox.new.employee_id(employee1.id).create

        manager = Manager::BaseQuery.preload_customers(manager, Customer::BaseQuery.new.employee_id(employee1.id))

        # the order of the customers seems to be somewhat random
        manager.customers.sort_by(&.id).should eq([customer1, customer3])
      end
    end

    it "does not modify original record" do
      with_lazy_load(enabled: false) do
        tag = TagBox.create
        original_post = PostBox.create
        TaggingBox.create &.tag_id(tag.id).post_id(original_post.id)

        Post::BaseQuery.preload_tags(original_post)

        expect_raises Avram::LazyLoadError do
          original_post.tags
        end
      end
    end
  end
end
