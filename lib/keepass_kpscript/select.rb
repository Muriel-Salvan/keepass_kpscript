module KeepassKpscript

  # Define rules to select entries from a Keepass database.
  # Those rules are taken from https://keepass.info/help/v2_dev/scr_sc_index.html#editentry
  class Select

    # Constructor
    def initialize
      @selectors = []
    end

    # Select a set of given field values
    #
    # Parameters::
    # * *selection* (Hash<String or Symbol, String>): Set of { field_name => field_value } to be selected.
    # Result::
    # * self: The selector itself, useful for chaining
    def fields(selection)
      selection.each do |field_name, field_value|
        @selectors << "-ref-#{field_name}:\"#{field_value}\""
      end
      self
    end

    # Select a UUID
    #
    # Parameters::
    # * *id* (String): The UUID
    # Result::
    # * self: The selector itself, useful for chaining
    def uuid(id)
      @selectors << "-refx-UUID:#{id}"
      self
    end

    # Select a list of tags
    #
    # Parameters::
    # * *lst_tags* (Array<String>): List of tags to select
    # Result::
    # * self: The selector itself, useful for chaining
    def tags(*lst_tags)
      @selectors << "-refx-Tags:\"#{lst_tags.flatten.join(',')}\""
      self
    end

    # Select entries that expire
    #
    # Parameters:
    # * *switch* (Boolean): Do we select entries that expire? [default = true]
    # Result::
    # * self: The selector itself, useful for chaining
    def expires(switch = true)
      @selectors << "-refx-Expires:#{switch ? 'true' : 'false'}"
      self
    end

    # Select entries that have expired
    #
    # Parameters:
    # * *switch* (Boolean): Do we select entries that have expired? [default = true]
    # Result::
    # * self: The selector itself, useful for chaining
    def expired(switch = true)
      @selectors << "-refx-Expired:#{switch ? 'true' : 'false'}"
      self
    end

    # Select entries that have a given parent group
    #
    # Parameters:
    # * *group_name* (String): Name of the parent group
    # Result::
    # * self: The selector itself, useful for chaining
    def group(group_name)
      @selectors << "-refx-Group:\"#{group_name}\""
      self
    end

    # Select entries that have a given group path
    #
    # Parameters:
    # * *group_path_entries* (Array<String>): Group path
    # Result::
    # * self: The selector itself, useful for chaining
    def group_path(*group_path_entries)
      @selectors << "-refx-GroupPath:\"#{group_path_entries.flatten.join('/')}\""
      self
    end

    # Select all entries
    #
    # Result::
    # * self: The selector itself, useful for chaining
    def all
      @selectors << '-refx-All'
      self
    end

    # Return the command-line string selecting the entries
    #
    # Result::
    # * String: The command-line string
    def to_s
      @selectors.join(' ')
    end

  end

end
