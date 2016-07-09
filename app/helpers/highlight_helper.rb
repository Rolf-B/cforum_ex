# -*- coding: utf-8 -*-

module HighlightHelper
  def parsed_highlighted_users
    highlighted_users = uconf('highlighted_users')
    highlighted_users ||= ''
    highlight_self = uconf('highlight_self') == 'yes' and not current_user.blank?

    user_map = {}

    unless highlighted_users.blank?
      highlighted_users.split(',').each do |s|
        user_map[s.strip.downcase] = true
      end
    end

    cu_nam = ''
    cu_nam = current_user.username.strip.downcase if not current_user.blank?

    return user_map, highlight_self, cu_nam
  end

  def check_threads_for_highlighting(threads)
    highlighted_users, highlight_self, cu_nam = parsed_highlighted_users
    return if highlighted_users.blank? and not highlight_self

    threads.each do |t|
      t.sorted_messages.each do |m|
        n = m.author.strip.downcase

        if highlighted_users[n]
          m.attribs['classes'] << 'highlighted-user'
          m.attribs['classes'] << user_to_class_name(m.author)
        end

        if highlight_self and n == cu_nam
          m.attribs['classes'] << 'highlighted-self'
          m.attribs['classes'] << user_to_class_name(m.author)
        end
      end
    end
  end

  def check_messages_for_highlight(messages)
    highlighted_users, highlight_self, cu_nam = parsed_highlighted_users
    return if highlighted_users.blank? and not highlight_self

    messages.each do |m|
      n = m.author.strip.downcase

      if highlighted_users[n]
        m.attribs['classes'] << 'highlighted-user'
        m.attribs['classes'] << user_to_class_name(m.author)
      end

      if highlight_self and n == cu_nam
        m.attribs['classes'] << 'highlighted-self'
        m.attribs['classes'] << user_to_class_name(m.author)
      end
    end
  end

  def highlight_showing_settings(user)
    @highlighted_users_list = User.where(username: user.conf('highlighted_users').split(/\s*,\s*/))
  end

  def highlight_saving_settings(settings)
    unless settings.options["highlighted_users"].blank?
      users = User.where(user_id: JSON.parse(settings.options["highlighted_users"]))
      settings.options["highlighted_users"] = (users.map {|u| u.username}).join(",")
    end
  end

  def highlight_notify_mention(mention, app)
    return unless app.current_user

    classes = []

    highlighted_users = app.uconf('highlighted_users')
    highlighted_users ||= ''
    highlight_self = app.uconf('highlight_self') == 'yes'

    return if highlighted_users.blank? and not highlight_self

    user_map = {}
    highlighted_users.split(',').each do |s|
      user_map[s.strip.downcase] = true
    end

    cu_nam = app.current_user.username.strip.downcase
    n = mention.first.strip.downcase

    if user_map[n]
      classes << '.highlighted-user'
      classes << "." + app.user_to_class_name(mention.first)
    end

    if highlight_self and n == cu_nam
      classes << '.highlighted-self'
      classes << "." + app.user_to_class_name(mention.first)
    end

    classes
  end

end

# eof
