class TentStatus.Views.Post extends TentStatus.View
  initialize: (options = {}) ->
    @parentView = options.parentView
    @template = @parentView?.partials['_post']

    @postId = @$el.attr('data-parent-id') || ""
    @postId = @$el.attr 'data-id' if @postId == ""
    @post = @parentView.posts.get(@postId)
    @parentPost = @post

    if @post?.isRepost() && @$el.attr('data-post-found') != 'yes'
      @$el.hide()
      post = new TentStatus.Models.Post { id: @post.get('content')['id'] }
      post.fetch
        success: =>
          return unless post.entity()
          @$el.show()
          @render @context(@post, @repostContext(@post, post))
          @post = post
    else
      @setup()

    @on 'ready', @setup
    @on 'ready', @bindViews
    @on 'ready', @bindEvents

  setup: =>
    @buttons = {
      reply: ($ '.navigation .reply', @$el)
      repost: ($ '.navigation .repost', @$el)
      delete: ($ '.navigation .delete', @$el)
    }

    @buttons.reply.on 'click', (e) =>
      e.preventDefault()
      @showReply()
      false

    @$reply = ($ '.reply-container', @$el).hide()

    @buttons.repost.on 'click', (e) =>
      e.preventDefault()
      @repost()
      false

    @buttons.delete.on 'click', (e)  =>
      e.preventDefault()
      @delete()
      false

  showReply: =>
    return if @post.get('entity') == TentStatus.current_entity
    @$reply.toggle()

  repost: =>
    return if @buttons.repost.hasClass 'disabled'
    return if @post.get('entity') == TentStatus.current_entity
    shouldRepost = confirm(@buttons.repost.attr 'data-confirm')
    return unless shouldRepost
    post = new TentStatus.Models.Post {
      type: "https://tent.io/types/post/repost/v0.1.0"
      content:
        entity: @post.get('entity')
        id: @post.get('id')
    }
    post.once 'sync', =>
      @buttons.repost.addClass 'disabled'
      TentStatus.Collections.posts.unshift(post)
      @parentView.emptyPool()
      @parentView.fetchPoolView.createPostView(post)
    post.save()

  delete: =>
    post = @post
    unless post == @parentPost
      post = @parentPost
    return unless post.get('entity') == TentStatus.current_entity
    shouldDelete = confirm(@buttons.delete.attr 'data-confirm')
    return unless shouldDelete
    @$el.hide()
    @post.destroy
      success: =>
        @$el.remove()
      error: =>
        @$el.show()

  replyToPost: (post) =>
    return unless post.get('mentions')?.length
    for mention in post.get('mentions')
      if mention.entity and mention.post
        mention.url = "#{TentStatus.url_root}entities/#{encodeURIComponent(mention.entity)}/#{mention.post}"
        mention.name = (_.find @parentView.follows(), (follow) => follow.get('entity') == mention.entity)?.name()
        mention.name ?= (_.find [@parentView.profile], (profile) => profile.entity() == mention.entity)?.name()
        return mention
    null

  repostContext: (post, repost) =>
    return false unless post.isRepost()

    repost ?= _.find @parentView.posts.toArray(), ((p) => p.get('id') == post.get('content')['id'])
    return false unless repost
    _.extend( @context(repost), { parent: { name: post.name(), id: post.get('id') } } )

  licenseName: (url) =>
    for l in @licenses || []
      return l.name if l.url == url
    url

  context: (post, repostContext) =>
    _.extend( post.toJSON(),
      isValid: true
      shouldShowReply: true
      isRepost: post.isRepost()
      repost: repostContext || @repostContext(post)
      inReplyTo: @replyToPost(post)
      url: "#{TentStatus.url_root}entities/#{encodeURIComponent(post.get('entity'))}/#{post.get('id')}"
      profileUrl: "#{TentStatus.url_root}entities/#{encodeURIComponent(post.get('entity'))}"
      name: post.name()
      hasName: post.hasName()
      avatar: post.avatar()
      licenses: _.map( post.get('licenses') || [], (url) => { name: @licenseName(url), url: url } )
      escaped:
        entity: encodeURIComponent(post.get('entity'))
      formatted:
        entity: TentStatus.Helpers.formatUrl post.get('entity')
        published_at: TentStatus.Helpers.formatTime post.get('published_at')
        full_published_at: TentStatus.Helpers.rawTime post.get('published_at')
      authenticated: TentStatus.authenticated
      guest_authenticated: TentStatus.guest_authenticated
      currentUserOwnsPost: TentStatus.current_entity == post.get('entity')
    )

  render: (context) =>
    html = @template.render(context, @parentView.partials)
    el = ($ html)
    @$el.replaceWith(el)
    @$el = el
    @trigger 'ready'

