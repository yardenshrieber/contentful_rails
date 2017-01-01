module ContentfulRails
  module NestedResource

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # Get a deeply-nested object from a string which represents the heirarchy.
      # The obvious use for this is to find an object from a URL
      # e.g. /grandparent/parent/child
      # @param [Symbol] the field to search by - for example, :slug
      # @param [String] the path as a forward-slash separated string
      def get_nested_from_path_by(field, path, opts = {})
        options = {delimiter: '/', unescape: false, prefix: ""}
        options.merge!(opts)

        path = CGI::unescape(path) if options[:unescape]
        delimiter = options[:delimiter]
        prefix = options[:prefix].empty? ? "" : "#{delimiter}#{options[:prefix]}#{delimiter}"

        root, *children = "#{prefix}#{path}".gsub(/^\//, '').split(delimiter)

        if field.to_sym == :id
          #we need to call find() to get by ID
          root_entity = find(root)
        else
          begin
            root_entity = search(field => root).first
          rescue Contentful::BadRequest
            #we have something which needs find_by called on it
            root_entity = find_by(field => root).first
          end
        end

        if root_entity && root_entity.has_children?
          return root_entity.get_child_entity_from_path_by(field, children)
        elsif root_entity
          return root_entity
        else
          return nil
        end
      end
    end

    # Given a field and an array of child fields, we need to recurse through them to get the last one
    # @param [Symbol] the field we need to search for
    # @param [Array] an array of field values to match against
    # @return an entity matching this class, which is the last in the tree
    def get_child_entity_from_path_by(field, children)
      # the next child in the path
      child_value = children.shift
      # get the child entity
      child = self.send(:children).find {|child| child.send(field) == child_value}
      if child && children.size > 0
        # we have some recursion to do - we're not at the end of the array
        # so call this method again with a smaller set of children
        child.get_child_entity_from_path_by(field, children)
      else
        return child #this is the final thing in the array - return it
      end
    end

    # Given a field (and optional delimiter), return a path to the current object.
    # e.g. you'd end up with /path/to/page (where this object is 'page')
    # @param [Symbol] the field to use to create the path
    # @param [String] the delimiter to use. Defaults to "/"
    # @return [String] the path as a string
    def nested_path_by(field, opts = {})
      options = {delimiter: "/", prefix: ""}
      options.merge!(opts)
      delimiter = options[:delimiter]
      prefix = options[:prefix].empty? ? "" : "#{options[:prefix]}#{delimiter}"
      path = ([self] + ancestors).reverse.collect {|a| a.send(field)}.join(delimiter).gsub(prefix,"")
      return delimiter + path
    end
  end
end
