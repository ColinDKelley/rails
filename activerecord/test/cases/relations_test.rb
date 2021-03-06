require "cases/helper"
require 'models/post'
require 'models/topic'
require 'models/comment'
require 'models/reply'
require 'models/author'
require 'models/comment'
require 'models/entrant'
require 'models/developer'
require 'models/company'

class RelationTest < ActiveRecord::TestCase
  fixtures :authors, :topics, :entrants, :developers, :companies, :developers_projects, :accounts, :categories, :categorizations, :posts, :comments

  def test_scoped
    topics = Topic.scoped
    assert_kind_of ActiveRecord::Relation, topics
    assert_equal 4, topics.size
  end

  def test_finding_with_conditions
    assert_equal ["David"], Author.where(:name => 'David').map(&:name)
    assert_equal ['Mary'],  Author.where(["name = ?", 'Mary']).map(&:name)
  end

  def test_finding_with_order
    topics = Topic.order('id')
    assert_equal 4, topics.size
    assert_equal topics(:first).title, topics.first.title
  end

  def test_finding_with_order_and_take
    entrants = Entrant.order("id ASC").limit(2).to_a

    assert_equal 2, entrants.size
    assert_equal entrants(:first).name, entrants.first.name
  end

  def test_finding_with_order_limit_and_offset
    entrants = Entrant.order("id ASC").limit(2).offset(1)

    assert_equal 2, entrants.size
    assert_equal entrants(:second).name, entrants.first.name

    entrants = Entrant.order("id ASC").limit(2).offset(2)
    assert_equal 1, entrants.size
    assert_equal entrants(:third).name, entrants.first.name
  end

  def test_finding_with_group
    developers = Developer.group("salary").select("salary").to_a
    assert_equal 4, developers.size
    assert_equal 4, developers.map(&:salary).uniq.size
  end

  def test_finding_with_hash_conditions_on_joined_table
    firms = DependentFirm.joins(:account).where({:name => 'RailsCore', :accounts => { :credit_limit => 55..60 }}).to_a
    assert_equal 1, firms.size
    assert_equal companies(:rails_core), firms.first
  end

  def test_find_all_with_join
    developers_on_project_one = Developer.joins('LEFT JOIN developers_projects ON developers.id = developers_projects.developer_id').
      where('project_id=1').to_a

    assert_equal 3, developers_on_project_one.length
    developer_names = developers_on_project_one.map { |d| d.name }
    assert developer_names.include?('David')
    assert developer_names.include?('Jamis')
  end

  def test_find_on_hash_conditions
    assert_equal Topic.find(:all, :conditions => {:approved => false}), Topic.where({ :approved => false }).to_a
  end

  def test_joins_with_string_array
    person_with_reader_and_post = Post.joins([
        "INNER JOIN categorizations ON categorizations.post_id = posts.id",
        "INNER JOIN categories ON categories.id = categorizations.category_id AND categories.type = 'SpecialCategory'"
      ]
    ).to_a
    assert_equal 1, person_with_reader_and_post.size
  end

  def test_scoped_responds_to_delegated_methods
    relation = Topic.scoped

    ["map", "uniq", "sort", "insert", "delete", "update"].each do |method|
      assert relation.respond_to?(method), "Topic.all should respond to #{method.inspect}"
    end
  end

  def test_find_with_readonly_option
    Developer.scoped.each { |d| assert !d.readonly? }
    Developer.scoped.readonly.each { |d| assert d.readonly? }
  end

  def test_eager_association_loading_of_stis_with_multiple_references
    authors = Author.eager_load(:posts => { :special_comments => { :post => [ :special_comments, :very_special_comment ] } }).
      order('comments.body, very_special_comments_posts.body').where('posts.id = 4').to_a

    assert_equal [authors(:david)], authors
    assert_no_queries do
      authors.first.posts.first.special_comments.first.post.special_comments
      authors.first.posts.first.special_comments.first.post.very_special_comment
    end
  end

  def test_find_with_included_associations
    assert_queries(2) do
      posts = Post.preload(:comments)
      posts.first.comments.first
    end

    assert_queries(2) do
      posts = Post.preload(:comments).to_a
      posts.first.comments.first
    end

    assert_queries(2) do
      posts = Post.preload(:author)
      posts.first.author
    end

    assert_queries(2) do
      posts = Post.preload(:author).to_a
      posts.first.author
    end
  end

    def test_default_scope_with_conditions_string
    assert_equal Developer.find_all_by_name('David').map(&:id).sort, DeveloperCalledDavid.scoped.to_a.map(&:id).sort
    assert_equal nil, DeveloperCalledDavid.create!.name
  end

  def test_default_scope_with_conditions_hash
    assert_equal Developer.find_all_by_name('Jamis').map(&:id).sort, DeveloperCalledJamis.scoped.map(&:id).sort
    assert_equal 'Jamis', DeveloperCalledJamis.create!.name
  end

  def test_loading_with_one_association
    posts = Post.preload(:comments)
    post = posts.find { |p| p.id == 1 }
    assert_equal 2, post.comments.size
    assert post.comments.include?(comments(:greetings))

    post = Post.where("posts.title = 'Welcome to the weblog'").preload(:comments).first
    assert_equal 2, post.comments.size
    assert post.comments.include?(comments(:greetings))

    posts = Post.preload(:last_comment)
    post = posts.find { |p| p.id == 1 }
    assert_equal Post.find(1).last_comment, post.last_comment
  end

  def test_loading_with_one_association_with_non_preload
    posts = Post.eager_load(:last_comment).order('comments.id DESC')
    post = posts.find { |p| p.id == 1 }
    assert_equal Post.find(1).last_comment, post.last_comment
  end
end

