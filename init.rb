require 'redmine'

require_dependency 'redmine_chyme/listener'
require_dependency 'redmine_chyme/viewlistener'

Redmine::Plugin.register :redmine_chyme do
	name 'Redmine Chyme'
	author 'Unvired Inc'
	url 'https://github.com/unvired/redmine_chyme'
	author_url 'http://unvired.com'
	description 'ChymeBot Messenger Integration'
	version '0.2'

	requires_redmine :version_or_higher => '0.8.0'

	settings \
		:default => {
			'callback_url' => nil,
			'assistant' => nil,
			'channel' => nil
		},
		:partial => 'settings/chyme_settings'
end
