module Webui::UserHelper
  def user_actions(user)
    safe_join(
      [
        link_to(edit_user_path(user.login)) do
          tag.i(nil, class: 'fas fa-edit text-secondary pr-1', title: 'Edit User')
        end,
        mail_to(user.email) do
          tag.i(nil, class: 'fas fa-envelope text-secondary pr-1', title: 'Send Email to User')
        end,
        render(partial: 'webui/users/delete_dialog.html.haml', locals: { user: user }),
        link_to('#', data: { toggle: 'modal', target: "#delete-user-modal-#{user}" }, title: 'Delete User') do
          tag.i(nil, class: 'fas fa-times-circle text-danger pr-1')
        end
      ]
    )
  end

  def user_with_realname_and_icon(user, opts = {})
    defaults = { short: false, no_icon: false }
    opts = defaults.merge(opts)

    user = User.find_by_login(user) unless user.is_a?(User)
    return '' unless user

    Rails.cache.fetch([user, 'realname_and_icon', opts, ::Configuration.first]) do
      realname = user.realname

      printed_name = if opts[:short] || realname.empty?
                       user.login
                     else
                       "#{realname} (#{user.login})"
                     end

      if opts[:no_icon]
        link_to(printed_name, user_path(user))
      else
        image_tag_for(user, size: 20) + ' ' + link_to(printed_name, user_path(user))
      end
    end
  end

  def requester_str(creator, requester_user, requester_group)
    # we don't need to show the requester if he is the same as the creator
    return if creator == requester_user

    if requester_user
      "the user #{user_with_realname_and_icon(requester_user, no_icon: true)}".html_safe
    elsif requester_group
      "the group #{requester_group}"
    end
  end

  def user_is_configurable(configuration, user)
    configuration.ldap_enabled? && !user.ignore_auth_services?
  end

  def activity_date_commits(projects)
    return tag.div(activity_date_commits_project(projects.first), class: 'h6 mt-3') if projects.size == 1

    max_projects = max_activity_items(3, projects)
    concat(tag.div(pluralize(projects.sum(&:last), 'commit'), class: 'h6 mt-3'))
    tag.ul do
      projects[0..(max_projects - 1)].each do |commit_row|
        concat(tag.li(activity_date_commits_project(commit_row), class: 'mt-1'))
      end
      diff = projects.size - max_projects
      concat(tag.li("and in #{pluralize(diff, 'project')} more", class: 'mt-1')) if diff.positive?
    end
  end

  private

  def activity_date_commits_project(commit_line)
    project, packages, count = commit_line

    return single_package_commits_line(project, packages.first.first, count) if packages.size == 1

    multiple_packages_commits_line(project, packages, count)
  end

  def multiple_packages_commits_line(project, packages, count)
    max_packages = max_activity_items(3, packages)
    capture do
      concat(pluralize(count, 'commit'))
      concat(' in ')
      concat(link_to(project, project_show_path(project)))
      tag.ul(class: 'mt-1') do
        packages = packages.sort_by { |_, c| -c }
        packages[0..(max_packages - 1)].each do |package, commit_count|
          tag.li do
            concat(pluralize(commit_count, 'commit'))
            concat(' in ')
            concat(link_to(package, package_show_path(project, package)))
          end
          count -= commit_count
        end
      end
      diff = packages.size - max_packages
      tag.li("and #{pluralize(count, 'commit')} in #{pluralize(diff, 'package')} more") if diff.positive?
    end
  end

  def single_package_commits_line(project, single_package, count)
    capture do
      concat(pluralize(count, 'commit'))
      concat(' in ')
      concat(link_to("#{project} / #{single_package}", package_show_path(project, single_package)))
    end
  end

  def max_activity_items(max_items, items_array)
    max_items += 1 if items_array.size == (max_items + 1)
    max_items
  end
end
