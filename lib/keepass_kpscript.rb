require 'keepass_kpscript/kpscript'

# Ruby API wrapping the KPScript CLI
module KeepassKpscript

  class << self

    # Get a KPScript instance from a given KPScript command line
    #
    # Parameters::
    # * *cmd* (String): KPScript command line
    # * *debug* (Boolean): Do we activate debugging logs? [default: false]
    #     Warning: Those logs can contain passwords and secrets from your database. Only use it in a local environment.
    # Result::
    # * Kpscript: A KPScript instance
    def use(cmd, debug: false)
      Kpscript.new(cmd, debug: debug)
    end

  end

end
