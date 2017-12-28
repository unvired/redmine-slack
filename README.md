## Chyme Messenger plugin for Redmine

This plugin posts updates to issues in your Redmine installation to a ChymeBot
channel. Please note that for the full functionality (Natural language queries, updates to issues etc),
the Redmine solution needs to be deployed and activated in Chyme.  If the solution is not activated only
the alerts will be displayed and no follow ups are possible.

Improvements are welcome! Just send a pull request.

## Acknowledgements

Many thanks to @sciyoshi for the project https://github.com/sciyoshi/redmine-slack on which this is based.

## Installation

From your Redmine plugins directory, clone this repository:

    git clone https://github.com/unvired/redmine_chyme.git

You will also need the `httpclient` dependency, which can be installed by running

    bundle install

from the plugin directory.

For managing conversations a database field has been added, run:

    bundle exec rake redmine:plugins:migrate NAME=redmine_chyme RAILS_ENV=production

Restart Redmine, and you should see the plugin show up in the Plugins page.
Under the configuration options, set the Chyme webhook URL to the URL for an
Incoming WebHook integration in your Chyme account.

Important:  Remember to remove any trailing / from the generated Chyme webhook URL.

## Customized Routing

You can also route messages to different channels on a per-project basis. To
do this, create a project custom field (Administration > Custom fields > Project)
named `Chyme Channel`. If no custom channel is defined for a project, the parent
project will be checked (or the default will be used). To prevent all notifications
from being sent for a project, set the custom channel to `-`.  In addition you will
also need to set `Chyme Assistant`.  If you want to use a different webhook URL also set `Chyme URL`

For more information, see http://www.redmine.org/projects/redmine/wiki/Plugins.
