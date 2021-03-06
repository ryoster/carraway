require 'sinatra'
require 'json'
require 'rack/flash'
require 'redcarpet'
require 'time'

module Carraway
  class Server < Sinatra::Base
    set :views, ::File.expand_path('../views', __FILE__)
    set :method_override, true
    enable :sessions
    use Rack::Flash

    get '/' do
      redirect '/carraway/'
    end

    get '/carraway/' do
      @categories = Category.all
      @category_posts = Post.all.group_by {|post| post.category.key }
      @category_posts.each do |category, posts|
        posts.sort_by!(&:updated).reverse!
      end
      erb :top
    end

    get '/carraway/api/posts' do
      posts = Post.all(published_only: true).map(&:to_h)

      # HACK Expand plugin
      transformed = params[:view] == 'html'
      if transformed
        markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
        posts = posts.map { |post| post[:body] = markdown.render(post[:body]); post }
      end

      { data: { posts: posts } }.to_json
    end

    get '/carraway/new' do
      @files = File.all
      erb :new
    end

    get %r{/carraway/edit/(\d+)} do |uid|
      @post = Post.find(uid)
      @files = File.all
      # FIXME handle not found
      erb :edit
    end

    get %r{/carraway/preview/(\d+)} do |uid|
      @post = Post.find(uid)
      # FIXME handle not found

      # Refresh GatsbyJS
      uri = URI.parse([Config.gatsby_endpoint, '/__refresh'].join)

      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Post.new(uri.path)
      res = http.request(req) # FIXME Handle errors

      redirect [Config.gatsby_endpoint, @post.path].join
    end

    post '/carraway/' do
      @post = Post.create(
        title: params[:title],
        body: params[:body],
        category_key: params[:category]
      )
      flash[:message] = 'Created'
      redirect "/carraway/edit/#{@post.uid}"
    end

    patch '/carraway/update' do
      @post = Post.find(params[:uid])
      # FIXME handle not found
      @post.assign(
        title: params[:title],
        body: params[:body]
      )
      # FIXME validation
      @post.save
      flash[:message] = 'Updated'
      redirect "/carraway/edit/#{@post.uid}"
    end

    patch '/carraway/publish' do
      @post = Post.find(params[:uid])
      # FIXME handle not found
      published =
        if params[:published] && params[:published].size > 0
          Time.parse(params[:published]).to_i
        else
          Time.now.to_i
        end

      @post.published = published
      # FIXME validation
      @post.save
      flash[:message] = 'Published'
      redirect "/carraway/edit/#{@post.uid}"
    end

    patch '/carraway/unpublish' do
      @post = Post.find(params[:uid])
      # FIXME handle not found
      @post.published = nil
      # FIXME validation
      @post.save
      flash[:message] = 'Unpublished'
      redirect "/carraway/edit/#{@post.uid}"
    end

    delete '/carraway/destroy' do
      @post = Post.find(params[:uid]) # FIXME handle not found
      @post.destroy
      flash[:message] = "Deleted #{@post.uid}"
      redirect "/carraway/"
    end

    get '/carraway/files' do
      @files = File.all
      erb :files
    end

    post '/carraway/files' do
      file = File.new(title: params[:title], file: params[:file])
      file.save # FIXME validation and error
      flash[:message] = "Saved #{file.path}"
      redirect "/carraway/files"
    end
  end
end
